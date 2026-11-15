-- FOOD-104: Процедура добавления блюда add_product(...)
CREATE OR REPLACE PROCEDURE zamaraeva_food.add_product(
    p_product_name        VARCHAR(150),
    p_product_category_id UUID,
    p_price               NUMERIC(12, 2),
    p_restaurant_id       UUID,
    p_photo_url           TEXT,
    p_rating              NUMERIC(3, 2),
    p_status zamaraeva_food.product_status,
    p_description         TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO zamaraeva_food.product (
        product_name,
        product_category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    )
    VALUES (
        p_product_name,
        p_product_category_id,
        p_price,
        p_restaurant_id,
        p_photo_url,
        p_rating,
        p_status,
        p_description
    );
END;
$$;

-- FOOD-105: Триггерная функция и триггер пересчёта рейтинга rating_change()
CREATE OR REPLACE FUNCTION zamaraeva_food.rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_type zamaraeva_food.review_entity_type;
    v_target UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_type := OLD.entity_type;
        v_target := OLD.entity_id;
    ELSE
        v_type := NEW.entity_type;
        v_target := NEW.entity_id;
    END IF;

    IF v_type = 'блюдо' THEN
        UPDATE zamaraeva_food.product
        SET rating = (
            SELECT ROUND(AVG(rating), 2)
            FROM zamaraeva_food.review
            WHERE entity_type = 'блюдо' AND entity_id = v_target
        )
        WHERE product_id = v_target;
    ELSIF v_type = 'ресторан' THEN
        UPDATE zamaraeva_food.restaurant
        SET rating = (
            SELECT ROUND(AVG(rating), 2)
            FROM zamaraeva_food.review
            WHERE entity_type = 'ресторан' AND entity_id = v_target
        )
        WHERE restaurant_id = v_target;
    END IF;

    IF TG_OP = 'UPDATE' AND (OLD.entity_type <> NEW.entity_type OR OLD.entity_id <> NEW.entity_id) THEN
        IF OLD.entity_type = 'блюдо' THEN
            UPDATE zamaraeva_food.product
            SET rating = (
                SELECT ROUND(AVG(rating), 2)
                FROM zamaraeva_food.review
                WHERE entity_type = 'блюдо' AND entity_id = OLD.entity_id
            )
            WHERE product_id = OLD.entity_id;
        ELSIF OLD.entity_type = 'ресторан' THEN
            UPDATE zamaraeva_food.restaurant
            SET rating = (
                SELECT ROUND(AVG(rating), 2)
                FROM zamaraeva_food.review
                WHERE entity_type = 'ресторан' AND entity_id = OLD.entity_id
            )
            WHERE restaurant_id = OLD.entity_id;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS rating_change_trigger ON zamaraeva_food.review;

CREATE TRIGGER rating_change_trigger
AFTER INSERT OR UPDATE OR DELETE ON zamaraeva_food.review
FOR EACH ROW
EXECUTE FUNCTION zamaraeva_food.rating_change();

-- Запрет смены пароля клиента
CREATE OR REPLACE FUNCTION zamaraeva_food.protect_client_password()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.password IS DISTINCT FROM OLD.password THEN
        IF COALESCE(current_setting('app.allow_password_change', true), 'false') <> 'true' THEN
            RAISE EXCEPTION 'Изменение пароля существующего пользователя запрещено без явного запроса на смену пароля';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_client_password ON zamaraeva_food.client;

CREATE TRIGGER trg_protect_client_password
BEFORE UPDATE ON zamaraeva_food.client
FOR EACH ROW
EXECUTE FUNCTION zamaraeva_food.protect_client_password();
