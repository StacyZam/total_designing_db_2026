-- FOOD-103: Процедура очистки тестовых данных erase_test_data()
CREATE OR REPLACE PROCEDURE zamaraeva_food.erase_test_data()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM zamaraeva_food.review;
    DELETE FROM zamaraeva_food.payment;
    DELETE FROM zamaraeva_food.order_structure;
    DELETE FROM zamaraeva_food."order";
    DELETE FROM zamaraeva_food.product;
    DELETE FROM zamaraeva_food.client_address;
    DELETE FROM zamaraeva_food.courier_pay;
    DELETE FROM zamaraeva_food.restaurant;
    DELETE FROM zamaraeva_food.product_category;
    DELETE FROM zamaraeva_food.courier;
    DELETE FROM zamaraeva_food.client;
    DELETE FROM zamaraeva_food.address;
END;
$$;

-- FOOD-102: Генератор тестовых данных insert_test_data(value int)
CREATE OR REPLACE PROCEDURE zamaraeva_food.insert_test_data(value int)
LANGUAGE plpgsql
AS $$
DECLARE
	-- ФИО
    v_last_names_m  text[] := ARRAY['Иванов', 'Смирнов', 'Кузнецов', 'Попов', 'Васильев', 'Петров', 'Соколов', 'Михайлов', 'Новиков', 'Фёдоров', 'Морозов', 'Волков', 'Алексеев', 'Лебедев', 'Семёнов'];
    v_first_names_m text[] := ARRAY['Иван', 'Александр', 'Максим', 'Дмитрий', 'Сергей', 'Андрей', 'Алексей', 'Артём', 'Илья', 'Кирилл', 'Михаил', 'Никита', 'Матвей', 'Роман', 'Егор'];
    v_patronymics_m text[] := ARRAY['Иванович', 'Александрович', 'Максимович', 'Дмитриевич', 'Сергеевич', 'Андреевич', 'Алексеевич', 'Артёмович', 'Ильич', 'Кириллович', 'Михайлович', 'Никитич', 'Матвеевич', 'Романович', 'Егорович'];

    v_last_names_f  text[] := ARRAY['Иванова', 'Смирнова', 'Кузнецова', 'Попова', 'Васильева', 'Петрова', 'Соколова', 'Михайлова', 'Новикова', 'Фёдорова', 'Морозова', 'Волкова', 'Алексеева', 'Лебедева', 'Семёнова'];
    v_first_names_f text[] := ARRAY['Анна', 'Мария', 'Елена', 'Дарья', 'Алина', 'Ирина', 'Екатерина', 'Арина', 'Полина', 'Ольга', 'Юлия', 'Татьяна', 'Наталья', 'Виктория', 'Ксения'];
    v_patronymics_f text[] := ARRAY['Ивановна', 'Александровна', 'Максимовна', 'Дмитриевна', 'Сергеевна', 'Андреевна', 'Алексеевна', 'Артёмовна', 'Ильинична', 'Кирилловна', 'Михайловна', 'Никитична', 'Матвеевна', 'Романовна', 'Егоровна'];

    -- Справочник улиц
    v_streets text[] := ARRAY[
        'ул. Ленина', 'пр-т Мира', 'ул. Гагарина', 'ул. Пушкина', 'ул. Советская',
        'ул. Кирова', 'ул. Садовая', 'ул. Центральная', 'ул. Молодёжная', 'ул. Набережная',
        'ул. Лермонтова', 'ул. Чехова', 'ул. Гоголя', 'пр-т Победы', 'ул. Строителей',
        'ул. Первомайская', 'ул. Комсомольская', 'ул. Октябрьская', 'ул. Северная', 'ул. Весенняя'
    ];

    -- Справочник ресторанов
    v_rest_names text[] := ARRAY[
        'Траттория Белла Италия', 'Токио Сакура Суши', 'Бургерная Мясо и Огонь', 'Грузинский Дворик Хинкали',
        'Пекарня Тёплый Хлеб', 'Паназиатское бистро Вок и Лапша', 'Стейк-хаус Прайм Гриль',
        'Домашняя кухня Уют', 'Кафе Веранда Вкуса', 'Смокерия Ребра и Брискет',
        'Пиццерия Неаполь', 'Суши-бар Киото', 'Гастробар Соль и Перец', 'Чайхана Восточный Сад', 'Бистро Французский Квартал'
    ];

    -- 10 базовых категорий блюд
    v_cat_names text[] := ARRAY[
        'Пицца', 'Роллы и суши', 'Бургеры', 'Супы', 'Салаты и закуски',
        'Горячие блюда', 'Паста и ризотто', 'Выпечка и хинкали', 'Десерты', 'Напитки'
    ];

    -- Названия блюд
    v_dishes_cat_1  text[] := ARRAY['Пицца Маргарита', 'Пицца Пепперони', 'Пицца Четыре сыра', 'Пицца Мясная Делюкс', 'Пицца Гавайская с ветчиной', 'Пицца Дьябола', 'Пицца Баварская', 'Пицца с грушей и горгонзолой'];
    v_dishes_cat_2  text[] := ARRAY['Ролл Филадельфия Классик', 'Ролл Калифорния с крабом', 'Ролл Запечённый с лососем', 'Ролл Дракон с угрём', 'Ролл Темпура с креветкой', 'Сет Токио Премиум', 'Суши Нигири с тунцом', 'Ролл Спайси Лосось'];
    v_dishes_cat_3  text[] := ARRAY['Классический Чизбургер с мраморной говядиной', 'Двойной Бургер с беконом и чеддером', 'Бургер BBQ с карамелизированным луком', 'Криспи Чикен Бургер', 'Трюфельный Бургер с бри', 'Гранд Бургер на бриоши'];
    v_dishes_cat_4  text[] := ARRAY['Суп Том Ям с морепродуктами', 'Борщ домашний с говядиной и сметаной', 'Крем-суп из белых грибов', 'Тыквенный крем-суп со сливками', 'Рамен с курицей терияки', 'Солянка сборная мясная', 'Суп Фо Бо с говядиной'];
    v_dishes_cat_5  text[] := ARRAY['Салат Цезарь с тигровыми креветками', 'Салат Цезарь с цыплёнком гриль', 'Греческий салат с фетой и маслинами', 'Тёплый салат с ростбифом', 'Брускетта с лососем и авокадо', 'Карпаччо из говядины с пармезаном'];
    v_dishes_cat_6  text[] := ARRAY['Стейк Рибай средней прожарки', 'Филе лосося на гриле с овощами', 'Бефстроганов с картофельным пюре', 'Медальоны из телятины с соусом демиглас', 'Утиная грудка с ягодным соусом', 'Котлеты из щуки со сливочным соусом'];
    v_dishes_cat_7  text[] := ARRAY['Паста Карбонара с гуанчиале', 'Феттуччине Альфредо с курицей и грибами', 'Спагетти Болоньезе с пармезаном', 'Паста Неро с морепродуктами', 'Ризотто с белыми грибами и трюфельным маслом', 'Лазанья мясная классическая'];
    v_dishes_cat_8  text[] := ARRAY['Хачапури по-аджарски с яйцом', 'Хачапури по-мегрельски с двойным сыром', 'Сет хинкали с говядиной и зеленью (5 шт.)', 'Сет хинкали с бараниной (5 шт.)', 'Фокачча с розмарином и чесноком', 'Пирог осетинский с сыром и шпинатом'];
    v_dishes_cat_9  text[] := ARRAY['Чизкейк Нью-Йорк классический', 'Тирамису по-итальянски с маскарпоне', 'Шоколадный фондан с шариком пломбира', 'Медовик со сметанным кремом', 'Наполеон с заварным кремом', 'Яблочный штрудель с корицей'];
    v_dishes_cat_10 text[] := ARRAY['Домашний лимонад Манго-Маракуйя (1 л)', 'Морс клюквенный домашний (1 л)', 'Свежевыжатый апельсиновый фреш', 'Раф-кофе солёная карамель', 'Чай облепиховый с имбирём и мёдом', 'Классический лимонад Тархун'];

    v_review_texts text[] := ARRAY[
        'Очень вкусно, привезли горячим и вовремя!',
        'Отличное качество продуктов, порции большие, обязательно закажем снова.',
        'В целом хорошо, но курьер немного задержался на светофорах.',
        'Прекрасная подача, тесто тонкое и начинки много.',
        'Всё свежее, упаковано аккуратно в фольгу и термопакет.',
        'Немного не хватило специй, но продукты свежие и качественные.',
        'Лучшая доставка в нашем городе, заказываем каждые выходные!'
    ];

    v_login_prefixes text[] := ARRAY['alex', 'dmitry', 'maxim', 'elena', 'anna', 'sergey', 'olga', 'ivan', 'maria', 'nikita', 'artem', 'ksenia', 'roman', 'polina', 'ilya'];

    -- Массивы сгенерированных ID текущего вызова
    v_rest_addr_ids   uuid[] := '{}';
    v_client_addr_ids uuid[] := '{}';
    v_client_ids      uuid[] := '{}';
    v_courier_ids     uuid[] := '{}';
    v_cat_ids         uuid[] := '{}';
    v_cat_types       int[]  := '{}';
    v_rest_ids        uuid[] := '{}';
    v_product_ids     uuid[] := '{}';
    v_order_ids       uuid[] := '{}';

    -- Вспомогательные переменные
    i                 int;
    j                 int;
    v_id              uuid;
    v_phone           char(12);
    v_login           varchar(50);
    v_fio             varchar(150);
    v_cat_name        varchar(100);
    v_cat_idx         int;
    v_dish_list       text[];
    v_dish_name       varchar(150);
    v_status_courier  zamaraeva_food.courier_status;
    v_status_rest     zamaraeva_food.restaurant_status;
    v_status_prod     zamaraeva_food.product_status;
    v_status_order    zamaraeva_food.order_status;
    v_pay_type        zamaraeva_food.payment_type;
    v_hire_date       date;
    v_dismiss_date    date;
    v_work_start      time;
    v_work_end        time;
    v_client_id       uuid;
    v_addr_id         uuid;
    v_rest_id         uuid;
    v_courier_id      uuid;
    v_prod_id         uuid;
    v_order_id        uuid;
    v_order_ts        timestamp;
    v_deliv_ts        timestamp;
    v_order_amount    numeric(12, 2);
    v_commission      numeric(12, 2);
    v_total_amount    numeric(12, 2);
    v_price           numeric(10, 2);
    v_qty             numeric(10, 3);
    v_rest_prods      uuid[];
    v_items_cnt       int;
    v_entity_type     zamaraeva_food.review_entity_type;
    v_entity_id       uuid;
    v_month_date      date;
    v_year            int;
    v_month           int;
    v_deliv_count     int;
    v_comm_sum        numeric(12, 2);
    v_curr_coeff      numeric(2, 1);
    v_next_coeff      numeric(2, 1);
BEGIN
    IF value IS NULL OR value <= 0 THEN
        RAISE EXCEPTION 'Параметр value должен быть положительным целым числом (получено: %)', value;
    END IF;
    -- 1. Генерация адресов: value*5 строк
    --    Первые value — под рестораны, остальные value*4 — под клиентов
    FOR i IN 1..(value * 5) LOOP
        v_id := exts.uuid_generate_v4();

        INSERT INTO zamaraeva_food.address (address_id, street, house_number, apartment_office)
        VALUES (
            v_id,
            v_streets[floor(random() * array_length(v_streets, 1))::int + 1],
            (floor(random() * 150)::int + 1)::text || CASE WHEN random() < 0.2 THEN 'А' ELSE '' END,
            CASE
                WHEN i <= value THEN 'офис ' || (floor(random() * 20)::int + 1)::text
                WHEN random() < 0.25 THEN NULL -- BR-3.2: частный дом без квартиры
                ELSE 'кв. ' || (floor(random() * 300)::int + 1)::text
            END
        );

        IF i <= value THEN
            v_rest_addr_ids := array_append(v_rest_addr_ids, v_id);
        ELSE
            v_client_addr_ids := array_append(v_client_addr_ids, v_id);
        END IF;
    END LOOP;

    -- 2. Генерация категорий блюд: value*1 строк
    FOR i IN 1..value LOOP
        v_id := exts.uuid_generate_v4();
        v_cat_idx := ((i - 1) % array_length(v_cat_names, 1)) + 1;
        v_cat_name := v_cat_names[v_cat_idx];

        IF EXISTS (SELECT 1 FROM zamaraeva_food.product_category WHERE product_category_name = v_cat_name) THEN
            v_cat_name := v_cat_name || ' №' || substring(md5(v_id::text), 1, 5);
        END IF;

        INSERT INTO zamaraeva_food.product_category (product_category_id, product_category_name)
        VALUES (v_id, v_cat_name);

        v_cat_ids   := array_append(v_cat_ids, v_id);
        v_cat_types := array_append(v_cat_types, v_cat_idx);
    END LOOP;

    -- 3. Генерация курьеров: value*1 строк
    FOR i IN 1..value LOOP
        v_id := exts.uuid_generate_v4();

        -- ФИО
        IF random() < 0.7 THEN
            v_fio := v_last_names_m[floor(random() * array_length(v_last_names_m, 1))::int + 1] || ' ' ||
                     v_first_names_m[floor(random() * array_length(v_first_names_m, 1))::int + 1] || ' ' ||
                     v_patronymics_m[floor(random() * array_length(v_patronymics_m, 1))::int + 1];
        ELSE
            v_fio := v_last_names_f[floor(random() * array_length(v_last_names_f, 1))::int + 1] || ' ' ||
                     v_first_names_f[floor(random() * array_length(v_first_names_f, 1))::int + 1] || ' ' ||
                     v_patronymics_f[floor(random() * array_length(v_patronymics_f, 1))::int + 1];
        END IF;

        LOOP
            v_phone := '+79' || lpad((floor(random() * 1000000000)::bigint)::text, 9, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM zamaraeva_food.courier WHERE phone_number = v_phone);
        END LOOP;

        v_status_courier := (enum_range(NULL::zamaraeva_food.courier_status))[
            floor(random() * cardinality(enum_range(NULL::zamaraeva_food.courier_status)))::int + 1
        ];
        IF i = 1 AND v_status_courier = 'уволен' THEN
            v_status_courier := 'свободен';
        END IF;

        v_hire_date := current_date - (floor(random() * 150)::int + 25);
        IF v_status_courier = 'уволен' THEN
            v_dismiss_date := v_hire_date + (floor(random() * 20)::int + 1);
        ELSE
            v_dismiss_date := NULL;
        END IF;

        INSERT INTO zamaraeva_food.courier (courier_id, fio, phone_number, status, hire_date, dismissal_date, coefficient)
        VALUES (v_id, v_fio, v_phone, v_status_courier, v_hire_date, v_dismiss_date, 0.1);

        v_courier_ids := array_append(v_courier_ids, v_id);
    END LOOP;

    -- 4. Генерация ресторанов: value*1 строк
    FOR i IN 1..value LOOP
        v_id := exts.uuid_generate_v4();

        v_status_rest := (enum_range(NULL::zamaraeva_food.restaurant_status))[
            floor(random() * cardinality(enum_range(NULL::zamaraeva_food.restaurant_status)))::int + 1
        ];
        -- Время работы: открытие 08:00..11:00, закрытие 20:00..23:30 (work_end > work_start, BR-4.4)
        v_work_start := make_time(8 + floor(random() * 4)::int, (floor(random() * 2)::int) * 30, 0);
        v_work_end   := make_time(20 + floor(random() * 4)::int, (floor(random() * 2)::int) * 30, 0);

        INSERT INTO zamaraeva_food.restaurant (
            restaurant_id, restaurant_name, address_id, description,
            work_start, work_end, company_details, rating, status
        )
        VALUES (
            v_id,
            v_rest_names[((i - 1) % array_length(v_rest_names, 1)) + 1] || ' #' || i::text,
            v_rest_addr_ids[i], 
            'Авторская и классическая кухня со свежими фермерскими продуктами и быстрой доставкой.',
            v_work_start,
            v_work_end,
            'ООО «ФудПартнёр ' || i::text || '», ИНН ' || (7700000000 + floor(random() * 99999999)::bigint)::text ||
            ', ОГРН ' || (1157700000000 + floor(random() * 999999999)::bigint)::text ||
            ', р/с 40702810' || lpad((floor(random() * 100000000000)::bigint)::text, 12, '0'),
            NULL, 
            v_status_rest
        );

        v_rest_ids := array_append(v_rest_ids, v_id);
    END LOOP;

    -- 5. Генерация клиентов: value * 1 строк 
    FOR i IN 1..value LOOP
        v_id := exts.uuid_generate_v4();

        LOOP
            v_login := v_login_prefixes[((i - 1) % array_length(v_login_prefixes, 1)) + 1] || '_' ||
                       substring(md5(random()::text), 1, 6);
            EXIT WHEN NOT EXISTS (SELECT 1 FROM zamaraeva_food.client WHERE login = v_login);
        END LOOP;

        LOOP
            v_phone := '+79' || lpad((floor(random() * 1000000000)::bigint)::text, 9, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM zamaraeva_food.client WHERE phone_number = v_phone);
        END LOOP;

        INSERT INTO zamaraeva_food.client (client_id, login, password, phone_number)
        VALUES (
            v_id,
            v_login,
            md5(random()::text),
            v_phone
        );

        v_client_ids := array_append(v_client_ids, v_id);

        FOR j IN 1..4 LOOP
            INSERT INTO zamaraeva_food.client_address (client_id, address_id)
            VALUES (v_id, v_client_addr_ids[(i - 1) * 4 + j])
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    -- 6. Генерация блюд: value*5 строк
    FOR i IN 1..(value * 5) LOOP
        v_id      := exts.uuid_generate_v4();
        v_rest_id := v_rest_ids[((i - 1) % value) + 1];
        j         := floor(random() * value)::int + 1;
        v_cat_idx := v_cat_types[j];

        CASE v_cat_idx
            WHEN 1  THEN v_dish_list := v_dishes_cat_1;
            WHEN 2  THEN v_dish_list := v_dishes_cat_2;
            WHEN 3  THEN v_dish_list := v_dishes_cat_3;
            WHEN 4  THEN v_dish_list := v_dishes_cat_4;
            WHEN 5  THEN v_dish_list := v_dishes_cat_5;
            WHEN 6  THEN v_dish_list := v_dishes_cat_6;
            WHEN 7  THEN v_dish_list := v_dishes_cat_7;
            WHEN 8  THEN v_dish_list := v_dishes_cat_8;
            WHEN 9  THEN v_dish_list := v_dishes_cat_9;
            ELSE         v_dish_list := v_dishes_cat_10;
        END CASE;

        v_dish_name := v_dish_list[floor(random() * array_length(v_dish_list, 1))::int + 1];

        v_status_prod := (enum_range(NULL::zamaraeva_food.product_status))[
            floor(random() * cardinality(enum_range(NULL::zamaraeva_food.product_status)))::int + 1
        ];

        v_price := round((450 + random() * 1000)::numeric, 2);

        INSERT INTO zamaraeva_food.product (
            product_id, product_name, product_category_id, price,
            restaurant_id, photo_url, rating, status, description
        )
        VALUES (
            v_id,
            v_dish_name,
            v_cat_ids[j],
            v_price,
            v_rest_id,
            CASE
                WHEN random() < 0.2 THEN NULL 
                ELSE 'https://cdn.foodexpress.ru/menu/' || md5(v_id::text) || '.jpg'
            END,
            NULL, 
            v_status_prod,
            'Свежеприготовленное блюдо «' || v_dish_name || '» по фирменному рецепту шеф-повара.'
        );

        v_product_ids := array_append(v_product_ids, v_id);
    END LOOP;

    -- 7. Генерация заказов (value*5), состава заказов (order_structure) и попыток оплаты (payment: value*5, ровно одна успешная на заказ)
    FOR i IN 1..(value * 5) LOOP
        v_order_id   := exts.uuid_generate_v4();
        v_client_id  := v_client_ids[((i - 1) % value) + 1];
        v_rest_id    := v_rest_ids[((i - 1) % value) + 1];
        v_courier_id := v_courier_ids[floor(random() * value)::int + 1];

        SELECT ca.address_id
          INTO v_addr_id
          FROM zamaraeva_food.client_address ca
         WHERE ca.client_id = v_client_id
         LIMIT 1;

        v_order_ts := date_trunc('second', localtimestamp - ((i * 3) % 175) * interval '1 day' - (floor(random() * 12)::int + 1) * interval '1 hour');

        IF i <= value THEN
            v_status_order := 'доставлен';
        ELSE
            v_status_order := (enum_range(NULL::zamaraeva_food.order_status))[
                floor(random() * cardinality(enum_range(NULL::zamaraeva_food.order_status)))::int + 1
            ];
        END IF;

        IF v_status_order = 'доставлен' THEN
            v_deliv_ts := v_order_ts + (floor(random() * 60)::int + 25) * interval '1 minute';
        ELSE
            v_deliv_ts := NULL;
        END IF;

        SELECT array_agg(p.product_id)
          INTO v_rest_prods
          FROM zamaraeva_food.product p
         WHERE p.restaurant_id = v_rest_id;

        v_items_cnt    := LEAST(array_length(v_rest_prods, 1), floor(random() * 2)::int + 2);
        v_order_amount := 0;

        FOR j IN 1..v_items_cnt LOOP
            SELECT p.price INTO v_price FROM zamaraeva_food.product p WHERE p.product_id = v_rest_prods[j];
            v_qty := (floor(random() * 2)::int + 2)::numeric;
            v_order_amount := v_order_amount + round(v_price * v_qty, 2);
        END LOOP;

        v_commission   := round(v_order_amount * 0.10, 2);
        v_total_amount := round(v_order_amount + v_commission, 2);

        INSERT INTO zamaraeva_food."order" (
            order_id, courier_id, client_id, address_id, restaurant_id,
            order_timestamp, delivery_timestamp, order_amount, commission,
            total_amount, status, pay_status, description
        )
        VALUES (
            v_order_id, v_courier_id, v_client_id, v_addr_id, v_rest_id,
            v_order_ts, v_deliv_ts, v_order_amount, v_commission,
            v_total_amount, v_status_order, 'оплачен',
            'Доставка заказа №' || i::text || ', домофон работает, позвонить за 5 минут.'
        );

        FOR j IN 1..v_items_cnt LOOP
            INSERT INTO zamaraeva_food.order_structure (order_id, product_id, quantity)
            VALUES (v_order_id, v_rest_prods[j], CASE WHEN j = 1 THEN 2 ELSE 2 END);
        END LOOP;

        SELECT round(sum(p.price * os.quantity), 2)
          INTO v_order_amount
          FROM zamaraeva_food.order_structure os
          JOIN zamaraeva_food.product p ON p.product_id = os.product_id
         WHERE os.order_id = v_order_id;

        v_commission   := round(v_order_amount * 0.10, 2);
        v_total_amount := round(v_order_amount + v_commission, 2);

        UPDATE zamaraeva_food."order"
           SET order_amount = v_order_amount,
               commission   = v_commission,
               total_amount = v_total_amount
         WHERE order_id = v_order_id;

        v_pay_type := (enum_range(NULL::zamaraeva_food.payment_type))[
            floor(random() * cardinality(enum_range(NULL::zamaraeva_food.payment_type)))::int + 1
        ];

        INSERT INTO zamaraeva_food.payment (
            payment_id, order_id, payment_type, amount,
            transaction_num, payment_timestamp, status
        )
        VALUES (
            exts.uuid_generate_v4(),
            v_order_id,
            v_pay_type,
            v_total_amount,
            'TXN-' || upper(md5(v_order_id::text || random()::text)),
            v_order_ts + interval '2 minutes',
            'успех'
        );

        v_order_ids := array_append(v_order_ids, v_order_id);
    END LOOP;

    -- 8. Генерация отзывов: value * 5 строк
    FOR i IN 1..(value * 5) LOOP
        v_order_id := v_order_ids[i];

        SELECT o.client_id, o.restaurant_id, o.order_timestamp
          INTO v_client_id, v_rest_id, v_order_ts
          FROM zamaraeva_food."order" o
         WHERE o.order_id = v_order_id;

        v_entity_type := (enum_range(NULL::zamaraeva_food.review_entity_type))[
            floor(random() * cardinality(enum_range(NULL::zamaraeva_food.review_entity_type)))::int + 1
        ];

        IF v_entity_type = 'блюдо' THEN
            SELECT os.product_id
              INTO v_entity_id
              FROM zamaraeva_food.order_structure os
             WHERE os.order_id = v_order_id
             LIMIT 1;
        ELSIF v_entity_type = 'ресторан' THEN
            v_entity_id := v_rest_id;
        ELSE
            v_entity_id := v_order_id;
        END IF;

        INSERT INTO zamaraeva_food.review (
            review_id, client_id, review_timestamp, entity_id,
            entity_type, order_id, description, photo_url, rating
        )
        VALUES (
            exts.uuid_generate_v4(),
            v_client_id,
            v_order_ts + interval '2 hours',
            v_entity_id,
            v_entity_type,
            v_order_id,
            v_review_texts[floor(random() * array_length(v_review_texts, 1))::int + 1],
            CASE
                WHEN random() < 0.3 THEN NULL 
                ELSE 'https://cdn.foodexpress.ru/reviews/' || md5(v_order_id::text || i::text) || '.jpg'
            END,
            (floor(random() * 5)::int + 1)::numeric(3, 2) 
        );
    END LOOP;

    UPDATE zamaraeva_food.product p
       SET rating = sub.avg_rating
      FROM (
          SELECT p2.product_id,
                 round(avg(r.rating), 2) AS avg_rating
            FROM zamaraeva_food.product p2
            LEFT JOIN zamaraeva_food.review r
              ON r.entity_type = 'блюдо' AND r.entity_id = p2.product_id
           GROUP BY p2.product_id
      ) sub
     WHERE p.product_id = sub.product_id;

    UPDATE zamaraeva_food.restaurant rst
       SET rating = sub.avg_rating
      FROM (
          SELECT r2.restaurant_id,
                 round(avg(rv.rating), 2) AS avg_rating
            FROM zamaraeva_food.restaurant r2
            LEFT JOIN zamaraeva_food.review rv
              ON rv.entity_type = 'ресторан' AND rv.entity_id = r2.restaurant_id
           GROUP BY r2.restaurant_id
      ) sub
     WHERE rst.restaurant_id = sub.restaurant_id;

    -- 9. Заполнение courier_pay за последние 6 месяцев 
    FOR i IN 1..array_length(v_courier_ids, 1) LOOP
        v_courier_id := v_courier_ids[i];
        v_curr_coeff := 0.1;

        SELECT c.status INTO v_status_courier
          FROM zamaraeva_food.courier c
         WHERE c.courier_id = v_courier_id;

        FOR v_month_date IN
            SELECT m::date
              FROM generate_series(
                  date_trunc('month', current_date - interval '5 months'),
                  date_trunc('month', current_date),
                  interval '1 month'
              ) AS m
             ORDER BY m ASC
        LOOP
            v_year  := extract(year  FROM v_month_date)::int;
            v_month := extract(month FROM v_month_date)::int;

            SELECT count(o.order_id),
                   coalesce(sum(o.commission), 0)
              INTO v_deliv_count, v_comm_sum
              FROM zamaraeva_food."order" o
             WHERE o.courier_id = v_courier_id
               AND o.status = 'доставлен'
               AND extract(year  FROM o.order_timestamp) = v_year
               AND extract(month FROM o.order_timestamp) = v_month;

            INSERT INTO zamaraeva_food.courier_pay (year, month, courier_id, amount, coefficient_used)
            VALUES (
                v_year,
                v_month,
                v_courier_id,
                round(v_comm_sum * v_curr_coeff, 2),
                v_curr_coeff
            )
            ON CONFLICT (year, month, courier_id) DO UPDATE
                SET amount           = EXCLUDED.amount,
                    coefficient_used = EXCLUDED.coefficient_used;

            IF v_deliv_count <= 150 THEN
                v_next_coeff := 0.1;
            ELSIF v_deliv_count <= 250 THEN
                v_next_coeff := 0.2;
            ELSIF v_deliv_count <= 500 THEN
                v_next_coeff := 0.3;
            ELSE
                v_next_coeff := 0.5;
            END IF;

            IF v_status_courier != 'уволен' THEN
                v_curr_coeff := v_next_coeff;
            END IF;
        END LOOP;

        UPDATE zamaraeva_food.courier
           SET coefficient = v_curr_coeff
         WHERE courier_id = v_courier_id;
    END LOOP;
END;
$$;