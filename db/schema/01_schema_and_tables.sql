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
    client_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(32) NOT NULL,
    phone_number CHAR(11) NOT NULL UNIQUE
);
-- 2.2. Адреса
CREATE TABLE zamaraeva_food.address (
    address_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    street VARCHAR(100) NOT NULL,
    house_number VARCHAR(20) NOT NULL,
    apartment_office VARCHAR(20)
);
-- 2.3. Адреса клиентов
CREATE TABLE zamaraeva_food.client_address (
    client_id UUID NOT NULL REFERENCES zamaraeva_food.client(client_id),
    address_id UUID NOT NULL REFERENCES zamaraeva_food.address(address_id),
    PRIMARY KEY (client_id, address_id)
);
-- 2.4. Рестораны
CREATE TABLE zamaraeva_food.restaurant (
    restaurant_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    restaurant_name VARCHAR(100) NOT NULL,
    address_id UUID NOT NULL UNIQUE REFERENCES zamaraeva_food.address(address_id),
    description TEXT NOT NULL,
    work_start TIME NOT NULL,
    work_end TIME NOT NULL,
    company_details TEXT NOT NULL,
    rating NUMERIC(3, 2),
    status zamaraeva_food.restaurant_status NOT NULL,
    CHECK (work_end > work_start),
    CHECK (rating BETWEEN 0 AND 5)
);
-- 2.5. Курьеры
CREATE TABLE zamaraeva_food.courier (
    courier_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    fio VARCHAR(150) NOT NULL,
    phone_number CHAR(11) NOT NULL,
    status zamaraeva_food.courier_status NOT NULL,
    hire_date DATE NOT NULL,
    dismissal_date DATE,
    coefficient NUMERIC(3, 1) NOT NULL DEFAULT 0.1,
    CHECK (coefficient BETWEEN 0.1 AND 0.5),
    CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date),
    CHECK (status <> 'уволен' OR dismissal_date IS NOT NULL)
);
-- 2.6. Оплата курьерам
CREATE TABLE zamaraeva_food.courier_pay (
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    courier_id UUID NOT NULL REFERENCES zamaraeva_food.courier(courier_id),
    amount NUMERIC(12, 2) NOT NULL,
    coefficient_used NUMERIC(3, 1) NOT NULL,
    PRIMARY KEY (year, month, courier_id),
    CHECK (month BETWEEN 1 AND 12),
    CHECK (amount >= 0),
    CHECK (coefficient_used BETWEEN 0.1 AND 0.5)
);
-- 2.7. Категории продуктов
CREATE TABLE zamaraeva_food.product_category (
    product_category_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_category_name VARCHAR(100) NOT NULL
);
-- 2.8. Продукты
CREATE TABLE zamaraeva_food.product (
    product_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_name VARCHAR(150) NOT NULL,
    product_category_id UUID NOT NULL REFERENCES zamaraeva_food.product_category(product_category_id),
    price NUMERIC(12, 2) NOT NULL,
    restaurant_id UUID NOT NULL REFERENCES zamaraeva_food.restaurant(restaurant_id),
    photo_url TEXT,
    rating NUMERIC(3, 2),
    status zamaraeva_food.product_status NOT NULL,
    description TEXT NOT NULL,
    CHECK (price >= 0),
    CHECK (rating BETWEEN 0 AND 5)
);
-- 2.9. Заказы
CREATE TABLE zamaraeva_food."order" (
    order_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    courier_id UUID NOT NULL REFERENCES zamaraeva_food.courier(courier_id),
    client_id UUID NOT NULL REFERENCES zamaraeva_food.client(client_id),
    address_id UUID NOT NULL REFERENCES zamaraeva_food.address(address_id),
    restaurant_id UUID NOT NULL REFERENCES zamaraeva_food.restaurant(restaurant_id),
    order_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivery_timestamp TIMESTAMP,
    order_amount NUMERIC(12, 2) NOT NULL,
    commission NUMERIC(12, 2) NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    status zamaraeva_food.order_status NOT NULL,
    pay_status zamaraeva_food.order_pay_status NOT NULL,
    description TEXT,
    FOREIGN KEY (client_id, address_id)
        REFERENCES zamaraeva_food.client_address(client_id, address_id),
    CHECK (order_amount >= 0),
    CHECK (commission = ROUND(order_amount * 0.10, 2)),
    CHECK (total_amount = order_amount + commission),
    CHECK (total_amount >= 1000),
    CHECK (delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp),
    CHECK (status <> 'доставлен' OR delivery_timestamp IS NOT NULL)
);
-- 2.10. Оплата
CREATE TABLE zamaraeva_food.payment (
    payment_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES zamaraeva_food."order"(order_id),
    payment_type zamaraeva_food.payment_type NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    transaction_id UUID NOT NULL UNIQUE DEFAULT exts.uuid_generate_v4(),
    payment_timestamp TIMESTAMP NOT NULL,
    status zamaraeva_food.payment_status NOT NULL,
    CHECK (amount >= 0)
);
-- Ограничения по оплате (1 успешная)
CREATE UNIQUE INDEX payment_one_success
ON zamaraeva_food.payment(order_id)
WHERE status = 'успех';

CREATE TABLE zamaraeva_food.order_structure (
    order_id UUID NOT NULL REFERENCES zamaraeva_food."order"(order_id),
    product_id UUID NOT NULL REFERENCES zamaraeva_food.product(product_id),
    quantity NUMERIC(12, 3) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CHECK (quantity > 0)
);
-- 2.11. Отзывы
CREATE TABLE zamaraeva_food.review (
    review_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES zamaraeva_food.client(client_id),
    review_timestamp TIMESTAMP NOT NULL,
    entity_id UUID NOT NULL,
    entity_type zamaraeva_food.review_entity_type NOT NULL,
    order_id UUID NOT NULL REFERENCES zamaraeva_food."order"(order_id),
    description TEXT NOT NULL,
    photo_url TEXT,
    rating NUMERIC(3, 2) NOT NULL,
    UNIQUE (order_id, entity_type, entity_id),
    CHECK (rating BETWEEN 1 AND 5)
);
