##*Обоснования ограничений*

###**Первичные ключи и типы**
- Все ID -- тип uuid, генерация через exts.uuid_generate_v4() (BR-11.1).
- Составные PK: client_address (client_id, address_id), order_structure (order_id, product_id), courier_pay (year, month, courier_id).
- 8 ENUM-типов вместо строк для всех статусов и типов (BR-11.5).

###**Уникальность (UNIQUE)**
- client: login и phone_number (BR-2.2).
- client_address: (client_id, address_id) -- адрес привязывается к клиенту один раз (BR-2.5).
- restaurant: address_id -- один адрес не может принадлежать двум ресторанам (BR-3.3).
- courier: phone_number (BR-6.1).
- courier_pay: (year, month, courier_id) -- одна выплата курьеру в месяц (BR-10.3).
- product_category: product_category_name (BR-5.7).
- order_structure: (order_id, product_id) -- без дублей блюд в одном заказе (BR-7.16).
- payment: transaction_num (внешний ID чека, BR-8.3) + частичный индекс (order_id) WHERE status = 'успех' -- ровно одна успешная оплата на заказ (BR-8.1).
- review: (order_id, entity_type, entity_id) -- максимум 1 отзыв на объект в рамках заказа (BR-9.5).

###**Внешние ключи (FOREIGN KEY)**
- client_address -> client, address (BR-2.4).
- restaurant -> address (BR-3.3).
- courier_pay -> courier (BR-10.2).
- product -> product_category, restaurant (BR-5.1).
- "order" -> courier, client, address, restaurant (BR-7.2, BR-7.5) + составной FK (client_id, address_id) -> client_address (доставка только на адрес этого клиента, BR-7.4).
- order_structure -> "order", product (BR-7.14).
- payment -> "order" (BR-8.1).
- review -> client, "order" (BR-9.2).

###**Проверки значений (CHECK)**
- Пустые строки: запрещены во всех строковых полях (length(btrim(...)) > 0, BR-11.3).
- Форматы: client.password -- 32 hex-символа MD5 (BR-2.3); телефоны -- +7 и 10 цифр (BR-2.1, BR-6.1).
- Диапазоны:
  * restaurant.rating и product.rating -- 0..5 или NULL (BR-4.2, BR-5.4, BR-9.7).
  * review.rating -- 1..5 (BR-9.4).
  * courier.coefficient и courier_pay.coefficient_used -- 0.1..0.5 (BR-6.4).
  * product.price >= 0 (BR-5.3), courier_pay.amount >= 0 (BR-10.4), order_structure.quantity > 0 (BR-7.15).
- Даты и время:
  * restaurant: work_end > work_start (BR-4.4).
  * courier: dismissal_date >= hire_date; если status = 'уволен', то dismissal_date IS NOT NULL (BR-6.3).
  * "order": delivery_timestamp >= order_timestamp (BR-7.13); если status = 'доставлен', то delivery_timestamp IS NOT NULL (BR-7.12).
- Деньги:
  * "order": commission = round(order_amount * 0.10, 2) (BR-1.4), total_amount = order_amount + commission (BR-7.10), total_amount >= 1000 (BR-1.8).
  * payment: amount >= 1000 (BR-8.4, BR-7.11).

###**Где разрешён NULL (BR-11.3)**
Все поля NOT NULL, кроме 7 столбцов:
1. address.apartment_office (BR-3.2)
2. restaurant.rating (BR-9.7)
3. product.photo_url (BR-5.6)
4. product.rating (BR-9.7)
5. courier.dismissal_date (BR-6.3)
6. "order".delivery_timestamp (BR-7.12)
7. review.photo_url (BR-9.3)