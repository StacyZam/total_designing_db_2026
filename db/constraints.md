# Обоснование ограничений

## Enum-типы

| Тип | Значения | BR |
|---|---|---|
| `zamaraeva_food.restaurant_status` | `'активен'`, `'неактивен'` | BR-4.3, BR-11.5 |
| `zamaraeva_food.product_status` | `'доступно'`, `'нет_в_наличии'`, `'архив'` | BR-5.5, BR-11.5 |
| `zamaraeva_food.courier_status` | `'свободен'`, `'занят'`, `'на_доставке'`, `'уволен'` | BR-6.2, BR-11.5 |
| `zamaraeva_food.order_status` | `'создан'`, `'готовится'`, `'в_доставке'`, `'доставлен'`, `'отменён'` | BR-7.7, BR-11.5 |
| `zamaraeva_food.order_pay_status` | `'ожидает'`, `'оплачен'`, `'ошибка'` | BR-7.9, BR-11.5 |
| `zamaraeva_food.payment_status` | `'успех'`, `'ошибка'`, `'в_обработке'` | BR-8.2, BR-11.5 |
| `zamaraeva_food.payment_type` | `'карта'`, `'наличные'`, `'безнал'` | BR-8.2, BR-11.5 |
| `zamaraeva_food.review_entity_type` | `'блюдо'`, `'ресторан'`, `'заказ'` | BR-9.1, BR-11.5 |

---

## Ловушки

### Сводная таблица решений

| Ловушка | Бизнес-правило | Как обошли (решение в коде) |
|---|---|---|
| **1. `payment` -- неполная сущность** | BR-8.2, BR-8.3, BR-8.6 | В `payment` добавлены 5 полей: `payment_type`, `amount`, `transaction_id` (`UUID UNIQUE`), `payment_timestamp`, `status`. Тип оплаты хранится в `payment`, т.к. у одного заказа могут быть попытки с разными способами оплаты. |
| **2. `order.address_id` -- адрес клиента** | BR-7.4 | Добавлен составной внешний ключ `FOREIGN KEY (client_id, address_id) REFERENCES client_address(client_id, address_id)`, который на уровне СУБД запрещает указать чужой адрес. |
| **3. `order_structure` -- один ресторан** | BR-7.3 | Контролируется на уровне формирования заказа (в `insert_test_data` блюда выбираются строго из массива блюд `v_rest_prods` ресторана заказа), чтобы не дублировать `restaurant_id` в `order_structure` и не нарушать схему `erd.md`. |
| **4. `review` -- полиморфизм** | BR-9.1, BR-9.2, BR-9.5 | Оставлена полиморфная связь (`entity_type` + `entity_id`) по `erd.md` без FK на `entity_id` (т.к. поле ссылается на 3 разные таблицы). Целостность в рамках заказа защищена `FK (order_id)` и `UNIQUE (order_id, entity_type, entity_id)`. |

### Ловушка 1: `payment` -- неполная сущность

**Какие атрибуты добавил в `payment` и почему** (BR-8.2):

```text
Добавлены: payment_type (способ оплаты), amount (сумма), transaction_id (внешний ID транзакции), payment_timestamp (время транзакции), status (статус попытки), потому что BR-8.2 и BR-8.3 требуют фиксации этих параметров для каждой попытки платежа.
```

**Где хранится тип оплаты -- `payment` или `order`** (BR-8.6):

```text
Тип оплаты (payment_type) хранится в payment, а не в order, потому что по BR-8.6 у одного заказа может быть несколько попыток оплаты разными способами.
```

### Ловушка 2: `order.address_id` -- принадлежность клиенту (BR-7.4)

**Как обеспечено, что адрес доставки принадлежит клиенту:**

```text
Реализовано через составной внешний ключ в таблице "order":
FOREIGN KEY (client_id, address_id) REFERENCES zamaraeva_food.client_address(client_id, address_id).
Так как (client_id, address_id) -- первичный ключ в client_address, СУБД гарантирует, что адрес доставки принадлежит именно этому клиенту.
```

### Ловушка 3: `order_structure` -- один ресторан в заказе (BR-7.3)

**Как обеспечено, что все блюда из `order.restaurant_id`:**

```text
Обеспечено на уровне логики формирования заказа и процедуры генерации данных (отбор блюд строго по restaurant_id заказа) без добавления столбца restaurant_id в order_structure, чтобы сохранить соответствие схеме erd.md и 3НФ (избежать избыточного дублирования ключа ресторана).
```

### Ловушка 4: `review` -- полиморфизм (BR-9.1)

**Как реализована валидность `review.entity_id`:**

```text
Реализован полиморфизм (entity_type + entity_id) согласно erd.md и FOOD-105. Прямой FK на entity_id невозможен, так как столбец условно ссылается на три разные таблицы (product, restaurant, "order"). Привязка к заказу обеспечена через FK (order_id) -> "order"(order_id) (BR-9.2) и UNIQUE (order_id, entity_type, entity_id) (BR-9.5).
```

---

## CHECK-ограничения

| Таблица | Столбец | Условие | BR | Обоснование |
|---|---|---|---|---|
| `restaurant` | `work_start`, `work_end` | `work_end > work_start` | BR-4.4 | `CHECK (work_end > work_start)`, потому что BR-4.4 требует, чтобы время закрытия было позже времени открытия. |
| `restaurant` | `rating` | `rating BETWEEN 0 AND 5` | BR-4.2 | `CHECK (rating BETWEEN 0 AND 5)`, потому что BR-4.2 задаёт диапазон рейтинга ресторана от 0 до 5. |
| `courier` | `coefficient` | `coefficient BETWEEN 0.1 AND 0.5` | BR-6.4 | `CHECK (coefficient BETWEEN 0.1 AND 0.5)`, потому что BR-6.4 ограничивает коэффициент курьера диапазоном 0.1–0.5. |
| `courier` | `hire_date`, `dismissal_date` | `dismissal_date IS NULL OR dismissal_date >= hire_date` | BR-6.1, BR-6.3 | `CHECK` дат найма и увольнения, потому что по BR-6.1 и BR-6.3 дата увольнения не может быть раньше даты найма. |
| `courier` | `status`, `dismissal_date` | `status <> 'уволен' OR dismissal_date IS NOT NULL` | BR-6.3 | `CHECK` даты увольнения, потому что BR-6.3 обязывает уволенного курьера иметь заполненную дату увольнения. |
| `courier_pay` | `month` | `month BETWEEN 1 AND 12` | BR-10.1, BR-10.2 | `CHECK (month BETWEEN 1 AND 12)`, потому что BR-10.1 и BR-10.2 требуют помесячного учёта зарплаты в рамках календарного года. |
| `courier_pay` | `amount` | `amount >= 0` | BR-10.4 | `CHECK (amount >= 0)`, потому что BR-10.4 требует неотрицательную сумму зарплаты курьера. |
| `courier_pay` | `coefficient_used` | `coefficient_used BETWEEN 0.1 AND 0.5` | BR-6.4, BR-10.2 | `CHECK` применённого коэффициента, потому что BR-6.4 и BR-10.2 задают диапазон коэффициентов от 0.1 до 0.5. |
| `product` | `price` | `price >= 0` | BR-5.3 | `CHECK (price >= 0)`, потому что BR-5.3 требует неотрицательную цену блюда. |
| `product` | `rating` | `rating BETWEEN 0 AND 5` | BR-5.4 | `CHECK (rating BETWEEN 0 AND 5)`, потому что BR-5.4 задаёт диапазон рейтинга блюда от 0 до 5. |
| `"order"` | `order_amount` | `order_amount >= 0` | BR-7.10 | `CHECK (order_amount >= 0)`, потому что BR-7.10 определяет сумму заказа через стоимость блюд, которая неотрицательна. |
| `"order"` | `commission` | `commission = ROUND(order_amount * 0.10, 2)` | BR-1.4, BR-7.10 | `CHECK` комиссии, потому что BR-1.4 и BR-7.10 фиксируют комиссию сервиса ровно в 10% от суммы без комиссии. |
| `"order"` | `total_amount` | `total_amount = order_amount + commission` | BR-1.5, BR-7.10 | `CHECK` общей суммы, потому что BR-1.5 и BR-7.10 определяют общую сумму как сумму без комиссии плюс комиссия. |
| `"order"` | `total_amount` | `total_amount >= 1000` | BR-1.8, BR-7.11 | `CHECK (total_amount >= 1000)`, потому что BR-1.8 и BR-7.11 запрещают заказы на общую сумму менее 1000 ₽. |
| `"order"` | `order_timestamp`, `delivery_timestamp` | `delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp` | BR-7.13 | `CHECK` времени доставки, потому что BR-7.13 запрещает время окончания доставки раньше времени создания заказа. |
| `"order"` | `status`, `delivery_timestamp` | `status <> 'доставлен' OR delivery_timestamp IS NOT NULL` | BR-7.12 | `CHECK` заполнения времени доставки, потому что BR-7.12 требует указания времени доставки для заказов в статусе `'доставлен'`. |
| `payment` | `amount` | `amount >= 0` | BR-8.2, BR-8.4 | `CHECK (amount >= 0)`, потому что по BR-8.2 и BR-8.4 сумма платежа соответствует неотрицательной сумме заказа. |
| `order_structure` | `quantity` | `quantity > 0` | BR-7.15 | `CHECK (quantity > 0)`, потому что BR-7.15 требует положительного количества блюда в позиции заказа. |
| `review` | `rating` | `rating BETWEEN 1 AND 5` | BR-9.4 | `CHECK (rating BETWEEN 1 AND 5)`, потому что BR-9.4 задаёт оценку в отзыве от 1 до 5. |

---

## UNIQUE-ограничения

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| `client` | `login` | BR-2.2 | `UNIQUE (login)`, потому что BR-2.2 требует уникальности логина клиента. |
| `client` | `phone_number` | BR-2.2 | `UNIQUE (phone_number)`, потому что BR-2.2 требует уникальности телефона клиента. |
| `client_address` | `(client_id, address_id)` (PK) | BR-2.5 | Составной PK, потому что BR-2.5 запрещает привязывать один адрес к одному клиенту дважды. |
| `restaurant` | `address_id` | BR-3.3, BR-3.4 | `UNIQUE (address_id)`, потому что BR-3.3 и BR-3.4 запрещают двум ресторанам делить один физический адрес. |
| `courier_pay` | `(year, month, courier_id)` (PK) | BR-10.3 | Составной PK, потому что BR-10.3 требует ровно одну запись о зарплате курьера за один месяц. |
| `payment` | `transaction_id` | BR-8.3 | `UNIQUE (transaction_id)`, потому что BR-8.3 требует уникальности внешнего идентификатора транзакции. |
| `payment` | `(order_id) WHERE status = 'успех'` | BR-8.1 | Частичный уникальный индекс `payment_one_success`, потому что BR-8.1 допускает только одну успешную оплату для заказа. |
| `order_structure` | `(order_id, product_id)` (PK) | BR-7.16 | Составной PK, потому что BR-7.16 запрещает дублирование одного и того же блюда в заказе. |
| `review` | `(order_id, entity_type, entity_id)` | BR-9.5 | `UNIQUE (order_id, entity_type, entity_id)`, потому что BR-9.5 разрешает не более одного отзыва на каждый объект в рамках одного заказа. |

---

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| `client_address` | `client_id` | `client(client_id)` | BR-2.4 | `FK (client_id)`, потому что BR-2.4 связывает адрес доставки с клиентом. |
| `client_address` | `address_id` | `address(address_id)` | BR-2.4, BR-3.5 | `FK (address_id)`, потому что BR-2.4 привязывает к клиенту существующий адрес из справочника. |
| `restaurant` | `address_id` | `address(address_id)` | BR-3.3 | `FK (address_id)`, потому что BR-3.3 требует наличия физического адреса у каждого ресторана. |
| `courier_pay` | `courier_id` | `courier(courier_id)` | BR-10.1, BR-10.2 | `FK (courier_id)`, потому что BR-10.1 и BR-10.2 начисляют выплату конкретному курьеру. |
| `product` | `product_category_id` | `product_category(product_category_id)` | BR-5.1 | `FK (product_category_id)`, потому что BR-5.1 требует принадлежности блюда ровно одной категории. |
| `product` | `restaurant_id` | `restaurant(restaurant_id)` | BR-5.1 | `FK (restaurant_id)`, потому что BR-5.1 требует принадлежности блюда ровно одному ресторану. |
| `"order"` | `courier_id` | `courier(courier_id)` | BR-1.3, BR-7.5 | `FK (courier_id)`, потому что по BR-1.3 и BR-7.5 каждый заказ доставляется курьером. |
| `"order"` | `client_id` | `client(client_id)` | BR-7.1, BR-7.2 | `FK (client_id)`, потому что BR-7.1 и BR-7.2 привязывают заказ к одному клиенту. |
| `"order"` | `address_id` | `address(address_id)` | BR-1.3, BR-7.4 | `FK (address_id)`, потому что BR-1.3 и BR-7.4 требуют доставки заказа по одному физическому адресу. |
| `"order"` | `(client_id, address_id)` | `client_address(client_id, address_id)` | BR-7.4 | Составной `FK (client_id, address_id)`, потому что BR-7.4 запрещает доставку на адрес, не принадлежащий клиенту заказа. |
| `"order"` | `restaurant_id` | `restaurant(restaurant_id)` | BR-7.2 | `FK (restaurant_id)`, потому что BR-7.2 привязывает заказ к одному ресторану. |
| `payment` | `order_id` | `"order"(order_id)` | BR-8.1 | `FK (order_id)`, потому что BR-8.1 связывает каждую попытку оплаты с заказом. |
| `order_structure` | `order_id` | `"order"(order_id)` | BR-7.14 | `FK (order_id)`, потому что BR-7.14 включает позиции в состав конкретного заказа. |
| `order_structure` | `product_id` | `product(product_id)` | BR-7.14 | `FK (product_id)`, потому что BR-7.14 связывает позицию заказа с конкретным блюдом. |
| `review` | `client_id` | `client(client_id)` | BR-9.1, BR-9.2 | `FK (client_id)`, потому что BR-9.1 и BR-9.2 требуют, чтобы отзыв оставлял клиент. |
| `review` | `order_id` | `"order"(order_id)` | BR-9.2 | `FK (order_id)`, потому что BR-9.2 обязывает привязывать каждый отзыв к конкретному заказу. |

---

## NOT NULL (только бизнес-обязательные)

| Таблица | Столбец | BR | Обоснование |
|---|---|---|---|
| `"order"` | `courier_id`, `address_id` | BR-1.3, BR-7.4, BR-7.5 | `NOT NULL`, потому что по BR-1.3 самовывоза нет, каждый заказ обязательно доставляется курьером по адресу. |
| `courier` | `coefficient` | BR-6.4, BR-6.5 | `NOT NULL`, потому что по BR-6.4 и BR-6.5 у каждого курьера всегда есть действующий коэффициент (при найме -- 0.1). |
| `payment` | `payment_type`, `amount`, `transaction_id`, `payment_timestamp`, `status` | BR-8.2, BR-11.3 | `NOT NULL`, потому что BR-8.2 и BR-11.3 требуют обязательной фиксации всех реквизитов попытки платежа. |

---

## NULL (осознанно разрешено)

| Таблица | Столбец | BR | Почему NULL |
|---|---|---|---|
| `address` | `apartment_office` | BR-3.2, BR-11.3 | По BR-3.2 квартира/офис необязательны (частные дома, отдельные здания). |
| `restaurant` | `rating` | BR-9.7 | По BR-9.7 при отсутствии отзывов на ресторан его рейтинг равен `NULL`. |
| `courier` | `dismissal_date` | BR-6.3, BR-11.3 | По BR-6.3 у работающего (не уволенного) курьера дата увольнения отсутствует. |
| `product` | `photo_url` | BR-5.6, BR-11.3 | По BR-5.6 ссылка на фотографию блюда необязательна. |
| `product` | `rating` | BR-9.7 | По BR-9.7 при отсутствии отзывов на блюдо его рейтинг равен `NULL`. |
| `"order"` | `delivery_timestamp` | BR-7.12, BR-11.3 | По BR-7.12 до перехода заказа в статус `'доставлен'` время окончания доставки пустое. |
| `"order"` | `description` | BR-7.1, BR-11.3 | Комментарий к заказу может отсутствовать при оформлении. |
| `review` | `photo_url` | BR-9.3, BR-11.3 | По BR-9.3 прикрепление фотографии к отзыву необязательно. |

---

## DEFAULT и GENERATED

| Таблица | Столбец | Что | Обоснование |
|---|---|---|---|
| Таблицы с UUID PK + `payment.transaction_id` | `*_id` | `DEFAULT exts.uuid_generate_v4()` | BR-11.1 требует генерации всех UUID на сервере через `exts.uuid_generate_v4()`. |
| `courier` | `coefficient` | `DEFAULT 0.1` | BR-6.5 устанавливает стартовый коэффициент нового курьера равным 0.1. |
| `"order"` | `order_timestamp` | `DEFAULT CURRENT_TIMESTAMP` | BR-7.1 и BR-11.2 требуют фиксации времени создания заказа в часовом поясе сервера. |
| `"order"` | `commission`, `total_amount` | Обычные поля `NUMERIC(12, 2)` с `CHECK` | Использованы обычные поля с `CHECK (commission = ROUND(order_amount * 0.10, 2))` и `CHECK (total_amount = order_amount + commission)` (BR-1.4, BR-7.10), чтобы позволить явную вставку сумм в `INSERT` (в т.ч. в `insert_test_data`) при строгом контроле формулы на уровне СУБД. |

---

## Нормализация (3НФ)

```text
Все таблицы схемы zamaraeva_food находятся в 3НФ: все атрибуты атомарны (1НФ), в таблицах с составным PK (client_address, order_structure, courier_pay) неключевые поля зависят от полного ключа (2НФ), транзитивные зависимости между неключевыми атрибутами отсутствуют (3НФ).

Особые случаи:
- order.commission и order.total_amount -- присутствуют в таблице "order" по erd.md; аномалии обновления исключены строгими ограничениями CHECK (BR-1.4, BR-7.10).
- product.rating и restaurant.rating -- контролируемая денормализация по требованию BR-9.6 и BR-9.7 для быстрого чтения рейтингов без агрегации review при каждом запросе; консистентность автоматически поддерживается триггером rating_change().
- review.entity_id + entity_type -- полиморфная связь (BR-9.1), оба атрибута функционально зависят только от review_id и не нарушают 3НФ.
```
