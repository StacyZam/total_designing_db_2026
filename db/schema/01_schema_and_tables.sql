-- FOOD-101: Физическая схема, ENUM-типы, таблицы и ограничения целостности
CREATE SCHEMA IF NOT EXISTS exts;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA exts;

CREATE SCHEMA IF NOT EXISTS zamaraeva_food;
SET search_path TO zamaraeva_food, exts, public;
-- 1. Создание 8 ENUM-типов
-- Статус ресторана 
CREATE TYPE zamaraeva_food.restaurant_status AS ENUM (
    'активен',
    'неактивен'
);
-- Статус блюда 
CREATE TYPE zamaraeva_food.product_status AS ENUM (
    'доступно',
    'нет_в_наличии',
    'архив'
);
-- Статус курьера 
CREATE TYPE zamaraeva_food.courier_status AS ENUM (
    'свободен',
    'занят',
    'на_доставке',
    'уволен'
);
-- Статус заказа 
CREATE TYPE zamaraeva_food.order_status AS ENUM (
    'создан',
    'готовится',
    'в_доставке',
    'доставлен',
    'отменён'
);
-- Агрегированный статус оплаты заказа
CREATE TYPE zamaraeva_food.order_pay_status AS ENUM (
    'ожидает',
    'оплачен',
    'ошибка'
);
-- Статус попытки платежа
CREATE TYPE zamaraeva_food.payment_status AS ENUM (
    'успех',
    'ошибка',
    'в_обработке'
);
-- Тип оплаты 
CREATE TYPE zamaraeva_food.payment_type AS ENUM (
    'карта',
    'наличные',
    'безнал'
);
-- Тип сущности отзыва
CREATE TYPE zamaraeva_food.review_entity_type AS ENUM (
    'блюдо',
    'ресторан',
    'заказ'
);

-- 2. Создание таблиц
-- 2.1. Клиенты
CREATE TABLE zamaraeva_food.client (
    client_id    uuid         PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login        varchar(50)  NOT NULL,
    password     varchar(32)  NOT NULL,
    phone_number char(12)     NOT NULL,
    CONSTRAINT uq_client_login UNIQUE (login),
    CONSTRAINT uq_client_phone UNIQUE (phone_number),
    CONSTRAINT chk_client_login_not_empty CHECK (length(btrim(login)) > 0),
    CONSTRAINT chk_client_password_md5 CHECK (password ~ '^[0-9a-f]{32}$'),
    CONSTRAINT chk_client_phone_format CHECK (phone_number ~ '^\+7[0-9]{10}$')
);
-- 2.2. Физические адреса
CREATE TABLE zamaraeva_food.address (
    address_id       uuid         PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    street           varchar(100) NOT NULL,
    house_number     varchar(20)  NOT NULL,
    apartment_office varchar(20)  NULL,
    CONSTRAINT chk_address_street_not_empty CHECK (length(btrim(street)) > 0),
    CONSTRAINT chk_address_house_not_empty  CHECK (length(btrim(house_number)) > 0),
    CONSTRAINT chk_address_apt_not_empty    CHECK (apartment_office IS NULL OR length(btrim(apartment_office)) > 0)
);
-- 2.3. Связь клиентов и адресов M:N 
CREATE TABLE zamaraeva_food.client_address (
    client_id  uuid NOT NULL,
    address_id uuid NOT NULL,
    CONSTRAINT pk_client_address PRIMARY KEY (client_id, address_id),
    CONSTRAINT fk_client_address_client  FOREIGN KEY (client_id)  REFERENCES zamaraeva_food.client(client_id)   ON DELETE RESTRICT,
    CONSTRAINT fk_client_address_address FOREIGN KEY (address_id) REFERENCES zamaraeva_food.address(address_id) ON DELETE RESTRICT
);
-- 2.4. Рестораны
CREATE TABLE zamaraeva_food.restaurant (
    restaurant_id   uuid                          PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    restaurant_name varchar(100)                  NOT NULL,
    address_id      uuid                          NOT NULL,
    description     text                          NOT NULL,
    work_start      time                          NOT NULL,
    work_end        time                          NOT NULL,
    company_details text                          NOT NULL,
    rating          numeric(3, 2)                 NULL,
    status          zamaraeva_food.restaurant_status NOT NULL DEFAULT 'активен',
    CONSTRAINT uq_restaurant_address UNIQUE (address_id),
    CONSTRAINT fk_restaurant_address FOREIGN KEY (address_id) REFERENCES zamaraeva_food.address(address_id) ON DELETE RESTRICT,
    CONSTRAINT chk_restaurant_name_not_empty    CHECK (length(btrim(restaurant_name)) > 0),
    CONSTRAINT chk_restaurant_desc_not_empty    CHECK (length(btrim(description)) > 0),
    CONSTRAINT chk_restaurant_details_not_empty CHECK (length(btrim(company_details)) > 0),
    CONSTRAINT chk_restaurant_work_hours        CHECK (work_end > work_start),
    CONSTRAINT chk_restaurant_rating            CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5))
);
-- 2.5. Курьеры
CREATE TABLE zamaraeva_food.courier (
    courier_id     uuid                       PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    fio            varchar(150)               NOT NULL,
    phone_number   char(12)                   NOT NULL,
    status         zamaraeva_food.courier_status NOT NULL DEFAULT 'свободен',
    hire_date      date                       NOT NULL,
    dismissal_date date                       NULL, 
    coefficient    numeric(2, 1)              NOT NULL DEFAULT 0.1,
    CONSTRAINT uq_courier_phone UNIQUE (phone_number),
    CONSTRAINT chk_courier_fio_not_empty   CHECK (length(btrim(fio)) > 0),
    CONSTRAINT chk_courier_phone_format    CHECK (phone_number ~ '^\+7[0-9]{10}$'),
    CONSTRAINT chk_courier_coefficient     CHECK (coefficient >= 0.1 AND coefficient <= 0.5),
    CONSTRAINT chk_courier_dates           CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date),
    CONSTRAINT chk_courier_dismissed_state CHECK (
        (status = 'уволен' AND dismissal_date IS NOT NULL) OR
        (status != 'уволен')
    )
);
-- 2.6. Зарплата курьеров
CREATE TABLE zamaraeva_food.courier_pay (
    year             int           NOT NULL,
    month            int           NOT NULL,
    courier_id       uuid          NOT NULL,
    amount           numeric(12,2) NOT NULL DEFAULT 0,
    coefficient_used numeric(2, 1) NOT NULL,
    CONSTRAINT pk_courier_pay PRIMARY KEY (year, month, courier_id),
    CONSTRAINT fk_courier_pay_courier FOREIGN KEY (courier_id) REFERENCES zamaraeva_food.courier(courier_id) ON DELETE RESTRICT,
    CONSTRAINT chk_courier_pay_year   CHECK (year >= 2020 AND year <= 2100),
    CONSTRAINT chk_courier_pay_month  CHECK (month >= 1 AND month <= 12),
    CONSTRAINT chk_courier_pay_amount CHECK (amount >= 0),
    CONSTRAINT chk_courier_pay_coeff  CHECK (coefficient_used >= 0.1 AND coefficient_used <= 0.5)
);
-- 2.7. Категории блюд
CREATE TABLE zamaraeva_food.product_category (
    product_category_id   uuid         PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_category_name varchar(100) NOT NULL,
    CONSTRAINT uq_product_category_name UNIQUE (product_category_name),
    CONSTRAINT chk_product_category_name_not_empty CHECK (length(btrim(product_category_name)) > 0)
);
-- 2.8. Блюда
CREATE TABLE zamaraeva_food.product (
    product_id          uuid                       PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_name        varchar(150)               NOT NULL,
    product_category_id uuid                       NOT NULL,
    price               numeric(10, 2)             NOT NULL,
    restaurant_id       uuid                       NOT NULL,
    photo_url           text                       NULL, 
    rating              numeric(3, 2)              NULL,
    status              zamaraeva_food.product_status NOT NULL DEFAULT 'доступно',
    description         text                       NOT NULL,
    CONSTRAINT fk_product_category   FOREIGN KEY (product_category_id) REFERENCES zamaraeva_food.product_category(product_category_id) ON DELETE RESTRICT,
    CONSTRAINT fk_product_restaurant FOREIGN KEY (restaurant_id)       REFERENCES zamaraeva_food.restaurant(restaurant_id)             ON DELETE RESTRICT,
    CONSTRAINT chk_product_name_not_empty  CHECK (length(btrim(product_name)) > 0),
    CONSTRAINT chk_product_desc_not_empty  CHECK (length(btrim(description)) > 0),
    CONSTRAINT chk_product_photo_not_empty CHECK (photo_url IS NULL OR length(btrim(photo_url)) > 0),
    CONSTRAINT chk_product_price           CHECK (price >= 0),
    CONSTRAINT chk_product_rating          CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5))
);
-- 2.9. Заказы
CREATE TABLE zamaraeva_food."order" (
    order_id           uuid                         PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    courier_id         uuid                         NOT NULL,
    client_id          uuid                         NOT NULL,
    address_id         uuid                         NOT NULL,
    restaurant_id      uuid                         NOT NULL,
    order_timestamp    timestamp                    NOT NULL,
    delivery_timestamp timestamp                    NULL,
    order_amount       numeric(12, 2)               NOT NULL,
    commission         numeric(12, 2)               NOT NULL,
    total_amount       numeric(12, 2)               NOT NULL,
    status             zamaraeva_food.order_status     NOT NULL DEFAULT 'создан',
    pay_status         zamaraeva_food.order_pay_status NOT NULL DEFAULT 'ожидает',
    description        text                         NOT NULL,
    CONSTRAINT fk_order_courier        FOREIGN KEY (courier_id)             REFERENCES zamaraeva_food.courier(courier_id)                      ON DELETE RESTRICT,
    CONSTRAINT fk_order_client         FOREIGN KEY (client_id)              REFERENCES zamaraeva_food.client(client_id)                        ON DELETE RESTRICT,
    CONSTRAINT fk_order_address        FOREIGN KEY (address_id)             REFERENCES zamaraeva_food.address(address_id)                      ON DELETE RESTRICT,
    CONSTRAINT fk_order_client_address FOREIGN KEY (client_id, address_id)  REFERENCES zamaraeva_food.client_address(client_id, address_id)    ON DELETE RESTRICT,
    CONSTRAINT fk_order_restaurant     FOREIGN KEY (restaurant_id)          REFERENCES zamaraeva_food.restaurant(restaurant_id)                ON DELETE RESTRICT,
    CONSTRAINT chk_order_desc_not_empty    CHECK (length(btrim(description)) > 0),
    CONSTRAINT chk_order_amount_positive   CHECK (order_amount > 0),
    CONSTRAINT chk_order_commission_calc   CHECK (commission = round(order_amount * 0.10, 2)),
    CONSTRAINT chk_order_total_calc        CHECK (total_amount = round(order_amount + commission, 2)),
    CONSTRAINT chk_order_min_total         CHECK (total_amount >= 1000),
    CONSTRAINT chk_order_delivery_time     CHECK (delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp),
    CONSTRAINT chk_order_delivered_has_ts  CHECK (status != 'доставлен' OR delivery_timestamp IS NOT NULL)
);
-- 2.10. Позиции заказа
CREATE TABLE zamaraeva_food.order_structure (
    order_id   uuid           NOT NULL,
    product_id uuid           NOT NULL,
    quantity   numeric(10, 3) NOT NULL,
    CONSTRAINT pk_order_structure PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_order_structure_order   FOREIGN KEY (order_id)   REFERENCES zamaraeva_food."order"(order_id)  ON DELETE RESTRICT,
    CONSTRAINT fk_order_structure_product FOREIGN KEY (product_id) REFERENCES zamaraeva_food.product(product_id) ON DELETE RESTRICT,
    CONSTRAINT chk_order_structure_qty    CHECK (quantity > 0)
);
-- 2.11. Попытки оплаты
CREATE TABLE zamaraeva_food.payment (
    payment_id        uuid                       PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id          uuid                       NOT NULL,
    payment_type      zamaraeva_food.payment_type   NOT NULL,
    amount            numeric(12, 2)             NOT NULL,
    transaction_num    varchar(100)               NOT NULL,
    payment_timestamp timestamp                  NOT NULL,
    status            zamaraeva_food.payment_status NOT NULL,
    CONSTRAINT uq_payment_transaction_num UNIQUE (transaction_num),
    CONSTRAINT fk_payment_order          FOREIGN KEY (order_id) REFERENCES zamaraeva_food."order"(order_id) ON DELETE RESTRICT,
    CONSTRAINT chk_payment_tx_not_empty  CHECK (length(btrim(transaction_num)) > 0),
    CONSTRAINT chk_payment_amount_min    CHECK (amount >= 1000)
);
-- Частичный уникальный индекс: не более одной успешной попытки оплаты на заказ
CREATE UNIQUE INDEX uq_payment_one_success_per_order
    ON zamaraeva_food.payment (order_id)
    WHERE status = 'успех';
-- 2.12. Отзывы 
CREATE TABLE zamaraeva_food.review (
    review_id        uuid                               PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id        uuid                               NOT NULL,
    review_timestamp timestamp                          NOT NULL,
    entity_id        uuid                               NOT NULL,
    entity_type      zamaraeva_food.review_entity_type  NOT NULL,
    order_id         uuid                               NOT NULL,
    description      text                               NOT NULL,
    photo_url        text                               NULL, 
    rating           numeric(3, 2)                      NOT NULL,
    CONSTRAINT uq_review_order_entity UNIQUE (order_id, entity_type, entity_id),
    CONSTRAINT fk_review_client       FOREIGN KEY (client_id) REFERENCES zamaraeva_food.client(client_id)   ON DELETE RESTRICT,
    CONSTRAINT fk_review_order        FOREIGN KEY (order_id)  REFERENCES zamaraeva_food."order"(order_id)  ON DELETE RESTRICT,
    CONSTRAINT chk_review_desc_not_empty  CHECK (length(btrim(description)) > 0),
    CONSTRAINT chk_review_photo_not_empty CHECK (photo_url IS NULL OR length(btrim(photo_url)) > 0),
    CONSTRAINT chk_review_rating          CHECK (rating >= 1 AND rating <= 5)
);
