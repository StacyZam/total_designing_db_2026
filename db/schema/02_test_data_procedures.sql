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
CREATE OR REPLACE PROCEDURE zamaraeva_food.insert_test_data(value INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_alphabet CONSTANT TEXT := 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';
    v_alpha_len CONSTANT INTEGER := LENGTH(v_alphabet);

    v_rest_statuses CONSTANT zamaraeva_food.restaurant_status[] := ENUM_RANGE(NULL::zamaraeva_food.restaurant_status);
    v_prod_statuses CONSTANT zamaraeva_food.product_status[] := ENUM_RANGE(NULL::zamaraeva_food.product_status);
    v_cour_statuses CONSTANT zamaraeva_food.courier_status[] := ENUM_RANGE(NULL::zamaraeva_food.courier_status);
    v_ord_statuses  CONSTANT zamaraeva_food.order_status[] := ENUM_RANGE(NULL::zamaraeva_food.order_status);
    v_pay_types     CONSTANT zamaraeva_food.payment_type[] := ENUM_RANGE(NULL::zamaraeva_food.payment_type);
    v_rev_types     CONSTANT zamaraeva_food.review_entity_type[] := ENUM_RANGE(NULL::zamaraeva_food.review_entity_type);

    v_client_ids UUID[] := '{}';
    v_address_ids UUID[] := '{}';
    v_rest_ids UUID[] := '{}';
    v_courier_ids UUID[] := '{}';
    v_cat_ids UUID[] := '{}';
    v_product_ids UUID[] := '{}';
    v_prices NUMERIC[] := '{}';
    v_rest_prods UUID[];
    v_rest_prices NUMERIC[];
    v_qtys INTEGER[];
    v_selected INTEGER[];

    v_id UUID;
    v_order_id UUID;
    v_entity_id UUID;
    v_rand_str TEXT;
    v_price NUMERIC(12, 2);
    v_order_amount NUMERIC(12, 2);
    v_commission NUMERIC(12, 2);
    v_total_amount NUMERIC(12, 2);
    v_order_ts TIMESTAMP;
    v_month_date TIMESTAMP;
    v_curr_month TIMESTAMP := DATE_TRUNC('month', LOCALTIMESTAMP);
    v_deliv_ts TIMESTAMP;
    v_curr_coeff NUMERIC(3, 1);
    v_next_coeff NUMERIC(3, 1);
    v_comm_sum NUMERIC(12, 2);
    v_hire_date DATE;
    v_dismiss_date DATE;
    v_work_start TIME;
    v_work_end TIME;
    v_status_courier zamaraeva_food.courier_status;
    v_status_order zamaraeva_food.order_status;
    v_pay_type zamaraeva_food.payment_type;
    v_entity_type zamaraeva_food.review_entity_type;
    v_deliv_count INTEGER;
    v_items_cnt INTEGER;
    v_qty INTEGER;
    v_client_idx INTEGER;
    v_addr_idx INTEGER;
    v_courier_idx INTEGER;
    i INTEGER;
    j INTEGER;
    k INTEGER;
BEGIN
    IF value IS NULL OR value < 1 THEN
        RAISE EXCEPTION 'value должен быть положительным';
    END IF;

    -- 1. Курьеры, клиенты, категории продуктов
    FOR i IN 1..value LOOP
        v_status_courier := CASE
            WHEN RANDOM() < 0.2 THEN 'уволен'::zamaraeva_food.courier_status
            ELSE v_cour_statuses[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_cour_statuses, 1))::INT]
        END;
        v_hire_date := CURRENT_DATE - (RANDOM() * 180)::INT;
        IF v_status_courier = 'уволен' THEN
            v_dismiss_date := v_hire_date + FLOOR(RANDOM() * (CURRENT_DATE - v_hire_date + 1))::INT;
        ELSE
            v_dismiss_date := NULL;
        END IF;

        v_rand_str := ARRAY_TO_STRING(ARRAY(
            SELECT SUBSTRING(v_alphabet, 1 + FLOOR(RANDOM() * v_alpha_len)::INT, 1)
            FROM GENERATE_SERIES(1, 6 + FLOOR(RANDOM() * 12)::INT + i * 0)
        ), '');

        INSERT INTO zamaraeva_food.courier (
            fio, phone_number, status, hire_date, dismissal_date, coefficient
        ) VALUES (
            v_rand_str,
            '7' || LPAD(FLOOR(RANDOM() * 10000000000)::BIGINT::TEXT, 10, '0'),
            v_status_courier,
            v_hire_date,
            v_dismiss_date,
            0.1
        ) RETURNING courier_id INTO v_id;
        v_courier_ids := ARRAY_APPEND(v_courier_ids, v_id);

        v_rand_str := ARRAY_TO_STRING(ARRAY(
            SELECT SUBSTRING(v_alphabet, 1 + FLOOR(RANDOM() * v_alpha_len)::INT, 1)
            FROM GENERATE_SERIES(1, 5 + FLOOR(RANDOM() * 8)::INT + i * 0)
        ), '');

        INSERT INTO zamaraeva_food.client (login, password, phone_number)
        VALUES (
            SUBSTRING(v_rand_str || '_' || MD5(RANDOM()::TEXT), 1, 100),
            MD5(RANDOM()::TEXT),
            '7' || LPAD(FLOOR(RANDOM() * 10000000000)::BIGINT::TEXT, 10, '0')
        ) RETURNING client_id INTO v_id;
        v_client_ids := ARRAY_APPEND(v_client_ids, v_id);

        v_rand_str := ARRAY_TO_STRING(ARRAY(
            SELECT SUBSTRING(v_alphabet, 1 + FLOOR(RANDOM() * v_alpha_len)::INT, 1)
            FROM GENERATE_SERIES(1, 5 + FLOOR(RANDOM() * 10)::INT + i * 0)
        ), '');

        INSERT INTO zamaraeva_food.product_category (product_category_name)
        VALUES (v_rand_str)
        RETURNING product_category_id INTO v_id;
        v_cat_ids := ARRAY_APPEND(v_cat_ids, v_id);
    END LOOP;

    IF NOT EXISTS (
        SELECT 1 FROM zamaraeva_food.courier WHERE status <> 'уволен'
    ) THEN
        UPDATE zamaraeva_food.courier
        SET status = 'свободен', dismissal_date = NULL
        WHERE courier_id = v_courier_ids[1];
    END IF;

    -- 2. Адреса
    FOR i IN 1..value * 5 LOOP
        v_rand_str := ARRAY_TO_STRING(ARRAY(
            SELECT SUBSTRING(v_alphabet, 1 + FLOOR(RANDOM() * v_alpha_len)::INT, 1)
            FROM GENERATE_SERIES(1, 6 + FLOOR(RANDOM() * 10)::INT + i * 0)
        ), '');

        INSERT INTO zamaraeva_food.address (street, house_number, apartment_office)
        VALUES (
            v_rand_str,
            (1 + FLOOR(RANDOM() * 200)::INT)::TEXT,
            CASE
                WHEN RANDOM() < 0.3 THEN NULL
                ELSE (1 + FLOOR(RANDOM() * 100)::INT)::TEXT
            END
        ) RETURNING address_id INTO v_id;
        v_address_ids := ARRAY_APPEND(v_address_ids, v_id);
    END LOOP;

    -- 3. Рестораны
    FOR i IN 1..value LOOP
        v_work_start := TIME '08:00' + FLOOR(RANDOM() * 6)::INT * INTERVAL '1 hour';
        v_work_end := v_work_start + (4 + FLOOR(RANDOM() * 6)::INT) * INTERVAL '1 hour';

        v_rand_str := ARRAY_TO_STRING(ARRAY(
            SELECT SUBSTRING(v_alphabet, 1 + FLOOR(RANDOM() * v_alpha_len)::INT, 1)
            FROM GENERATE_SERIES(1, 6 + FLOOR(RANDOM() * 12)::INT + i * 0)
        ), '');

        INSERT INTO zamaraeva_food.restaurant (
            restaurant_name, address_id, description, work_start, work_end,
            company_details, status
        ) VALUES (
            v_rand_str,
            v_address_ids[i],
            SUBSTRING(MD5(RANDOM()::TEXT), 1, 1 + FLOOR(RANDOM() * 31)::INT),
            v_work_start,
            v_work_end,
            SUBSTRING(MD5(RANDOM()::TEXT), 1, 1 + FLOOR(RANDOM() * 31)::INT),
            v_rest_statuses[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_rest_statuses, 1))::INT]
        ) RETURNING restaurant_id INTO v_id;
        v_rest_ids := ARRAY_APPEND(v_rest_ids, v_id);
    END LOOP;

    -- 4. Адреса клиентов
    FOR i IN 1..value * 4 LOOP
        j := ((i - 1) / 4) + 1;
        INSERT INTO zamaraeva_food.client_address (client_id, address_id)
        VALUES (v_client_ids[j], v_address_ids[value + i]);
    END LOOP;

    -- 5. Блюда
    FOR i IN 1..value * 5 LOOP
        j := ((i - 1) % value) + 1;
        v_price := 1000 + FLOOR(RANDOM() * 4000)::INT;

        v_rand_str := ARRAY_TO_STRING(ARRAY(
            SELECT SUBSTRING(v_alphabet, 1 + FLOOR(RANDOM() * v_alpha_len)::INT, 1)
            FROM GENERATE_SERIES(1, 5 + FLOOR(RANDOM() * 12)::INT + i * 0)
        ), '');

        INSERT INTO zamaraeva_food.product (
            product_name, product_category_id, price, restaurant_id,
            photo_url, status, description
        ) VALUES (
            v_rand_str,
            v_cat_ids[1 + FLOOR(RANDOM() * value)::INT],
            v_price,
            v_rest_ids[j],
            CASE
                WHEN RANDOM() < 0.5 THEN NULL
                ELSE 'https://cdn.foodexpress.ru/img/' || MD5(RANDOM()::TEXT) || '.jpg'
            END,
            v_prod_statuses[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_prod_statuses, 1))::INT],
            SUBSTRING(MD5(RANDOM()::TEXT), 1, 1 + FLOOR(RANDOM() * 31)::INT)
        ) RETURNING product_id INTO v_id;
        v_product_ids := ARRAY_APPEND(v_product_ids, v_id);
        v_prices := ARRAY_APPEND(v_prices, v_price);
    END LOOP;

    -- 6. Заказы, состав заказов, оплаты и отзывы
    FOR i IN 1..value * 5 LOOP
        j := ((i - 1) % value) + 1;
        v_client_idx := 1 + FLOOR(RANDOM() * value)::INT;
        v_addr_idx := value + (v_client_idx - 1) * 4 + 1 + FLOOR(RANDOM() * 4)::INT;
        v_courier_idx := 1 + FLOOR(RANDOM() * value)::INT;

        v_rest_prods := ARRAY[
            v_product_ids[j],
            v_product_ids[j + value],
            v_product_ids[j + 2 * value],
            v_product_ids[j + 3 * value],
            v_product_ids[j + 4 * value]
        ];
        v_rest_prices := ARRAY[
            v_prices[j],
            v_prices[j + value],
            v_prices[j + 2 * value],
            v_prices[j + 3 * value],
            v_prices[j + 4 * value]
        ];
        v_items_cnt := 1 + FLOOR(RANDOM() * 5)::INT;
        v_selected := '{}';
        WHILE COALESCE(ARRAY_LENGTH(v_selected, 1), 0) < v_items_cnt LOOP
            k := 1 + FLOOR(RANDOM() * 5)::INT;
            IF NOT k = ANY(v_selected) THEN
                v_selected := ARRAY_APPEND(v_selected, k);
            END IF;
        END LOOP;

        v_qtys := '{}';
        v_order_amount := 0;
        FOR k IN 1..v_items_cnt LOOP
            v_qty := 1 + FLOOR(RANDOM() * 5)::INT;
            v_qtys := ARRAY_APPEND(v_qtys, v_qty);
            v_order_amount := v_order_amount + ROUND(v_rest_prices[v_selected[k]] * v_qty, 2);
        END LOOP;
        v_commission := ROUND(v_order_amount * 0.10, 2);
        v_total_amount := v_order_amount + v_commission;

        v_order_ts := LOCALTIMESTAMP - (RANDOM() * 180)::INT * INTERVAL '1 day';
        IF v_order_ts > LOCALTIMESTAMP - INTERVAL '3 hours' THEN
            v_order_ts := LOCALTIMESTAMP - INTERVAL '3 hours';
        END IF;

        v_status_order := v_ord_statuses[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_ord_statuses, 1))::INT];
        v_pay_type := v_pay_types[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_pay_types, 1))::INT];
        v_entity_type := v_rev_types[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_rev_types, 1))::INT];

        IF v_status_order = 'доставлен' THEN
            v_deliv_ts := v_order_ts + INTERVAL '1 hour';
        ELSE
            v_deliv_ts := NULL;
        END IF;

        INSERT INTO zamaraeva_food."order" (
            courier_id, client_id, address_id, restaurant_id,
            order_timestamp, delivery_timestamp, order_amount,
            commission, total_amount, status, pay_status, description
        ) VALUES (
            v_courier_ids[v_courier_idx],
            v_client_ids[v_client_idx],
            v_address_ids[v_addr_idx],
            v_rest_ids[j],
            v_order_ts,
            v_deliv_ts,
            v_order_amount,
            v_commission,
            v_total_amount,
            v_status_order,
            'оплачен',
            SUBSTRING(MD5(RANDOM()::TEXT), 1, 1 + FLOOR(RANDOM() * 31)::INT)
        ) RETURNING order_id INTO v_order_id;

        FOR k IN 1..v_items_cnt LOOP
            INSERT INTO zamaraeva_food.order_structure (order_id, product_id, quantity)
            VALUES (v_order_id, v_rest_prods[v_selected[k]], v_qtys[k]);
        END LOOP;

        INSERT INTO zamaraeva_food.payment (
            order_id, payment_type, amount, transaction_id,
            payment_timestamp, status
        ) VALUES (
            v_order_id,
            v_pay_type,
            v_total_amount,
            exts.uuid_generate_v4(),
            v_order_ts + INTERVAL '30 minutes',
            'успех'
        );

        v_entity_id := CASE v_entity_type
            WHEN 'блюдо' THEN v_rest_prods[v_selected[1 + FLOOR(RANDOM() * v_items_cnt)::INT]]
            WHEN 'ресторан' THEN v_rest_ids[j]
            ELSE v_order_id
        END;

        INSERT INTO zamaraeva_food.review (
            client_id, review_timestamp, entity_id, entity_type,
            order_id, description, photo_url, rating
        ) VALUES (
            v_client_ids[v_client_idx],
            v_order_ts + INTERVAL '2 hours',
            v_entity_id,
            v_entity_type,
            v_order_id,
            SUBSTRING(MD5(RANDOM()::TEXT), 1, 1 + FLOOR(RANDOM() * 31)::INT),
            CASE
                WHEN RANDOM() < 0.5 THEN NULL
                ELSE 'https://cdn.foodexpress.ru/img/' || MD5(RANDOM()::TEXT) || '.jpg'
            END,
            1 + FLOOR(RANDOM() * 5)::INT
        );
    END LOOP;

    -- 7. Пересчёт рейтингов
    UPDATE zamaraeva_food.product p
    SET rating = (
        SELECT ROUND(AVG(r.rating), 2)
        FROM zamaraeva_food.review r
        WHERE r.entity_type = 'блюдо'
          AND r.entity_id = p.product_id
    );

    UPDATE zamaraeva_food.restaurant t
    SET rating = (
        SELECT ROUND(AVG(r.rating), 2)
        FROM zamaraeva_food.review r
        WHERE r.entity_type = 'ресторан'
          AND r.entity_id = t.restaurant_id
    );

    -- 8. Расчёт выплат курьерам за последние 6 месяцев
    FOR j IN 1..value LOOP
        SELECT status INTO v_status_courier
        FROM zamaraeva_food.courier
        WHERE courier_id = v_courier_ids[j];

        v_curr_coeff := 0.1;
        FOR v_month_date IN
            SELECT GENERATE_SERIES(
                DATE_TRUNC('month', LOCALTIMESTAMP) - INTERVAL '5 months',
                DATE_TRUNC('month', LOCALTIMESTAMP),
                INTERVAL '1 month'
            )
        LOOP
            SELECT COUNT(*), COALESCE(SUM(commission), 0)
            INTO v_deliv_count, v_comm_sum
            FROM zamaraeva_food."order"
            WHERE courier_id = v_courier_ids[j]
              AND status = 'доставлен'
              AND order_timestamp >= v_month_date
              AND order_timestamp < v_month_date + INTERVAL '1 month';

            INSERT INTO zamaraeva_food.courier_pay (
                year, month, courier_id, amount, coefficient_used
            ) VALUES (
                EXTRACT(YEAR FROM v_month_date)::INT,
                EXTRACT(MONTH FROM v_month_date)::INT,
                v_courier_ids[j],
                ROUND(v_curr_coeff * v_comm_sum, 2),
                v_curr_coeff
            )
            ON CONFLICT (year, month, courier_id)
            DO UPDATE SET amount = EXCLUDED.amount,
                          coefficient_used = EXCLUDED.coefficient_used;

            v_next_coeff := CASE
                WHEN v_deliv_count <= 150 THEN 0.1
                WHEN v_deliv_count <= 250 THEN 0.2
                WHEN v_deliv_count <= 500 THEN 0.3
                ELSE 0.5
            END;

            IF v_month_date < v_curr_month OR v_status_courier <> 'уволен' THEN
                v_curr_coeff := v_next_coeff;
            END IF;
        END LOOP;

        UPDATE zamaraeva_food.courier
        SET coefficient = v_curr_coeff
        WHERE courier_id = v_courier_ids[j];
    END LOOP;
END;
$$;
