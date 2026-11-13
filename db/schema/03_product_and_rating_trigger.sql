-- FOOD-104: Процедура добавления блюда add_product(...)
CREATE OR REPLACE PROCEDURE zamaraeva_food.add_product(
    p_restaurant_id       uuid,
    p_product_category_id uuid,
    p_name                varchar,
    p_price               numeric,
    p_rating              numeric                    DEFAULT NULL,
    p_status              zamaraeva_food.product_status DEFAULT 'доступно',
    p_description         text                       DEFAULT 'Описание блюда',
    p_photo_url           text                       DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_restaurant_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM zamaraeva_food.restaurant r WHERE r.restaurant_id = p_restaurant_id
    ) THEN
        RAISE EXCEPTION 'Ошибка добавления блюда: ресторан с идентификатором % не существует.', p_restaurant_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    IF p_product_category_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM zamaraeva_food.product_category pc WHERE pc.product_category_id = p_product_category_id
    ) THEN
        RAISE EXCEPTION 'Ошибка добавления блюда: категория с идентификатором % не существует.', p_product_category_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    IF p_name IS NULL OR length(btrim(p_name)) = 0 THEN
        RAISE EXCEPTION 'Ошибка добавления блюда: название блюда не может быть пустым.'
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_price IS NULL OR p_price < 0 THEN
        RAISE EXCEPTION 'Ошибка добавления блюда: цена блюда (%) не может быть отрицательной (BR-5.3).', p_price
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_rating IS NOT NULL AND (p_rating < 0 OR p_rating > 5) THEN
        RAISE EXCEPTION 'Ошибка добавления блюда: рейтинг блюда (%) должен быть в диапазоне от 0 до 5 (BR-5.4).', p_rating
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_description IS NULL OR length(btrim(p_description)) = 0 THEN
        RAISE EXCEPTION 'Ошибка добавления блюда: описание блюда не может быть пустым.'
            USING ERRCODE = 'check_violation';
    END IF;

    INSERT INTO zamaraeva_food.product (
        product_id,
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
        exts.uuid_generate_v4(),
        p_name,
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
BEGIN
    IF TG_OP IN ('DELETE', 'UPDATE') THEN
        IF OLD.entity_type = 'блюдо' THEN
            UPDATE zamaraeva_food.product
               SET rating = (
                   SELECT round(avg(r.rating), 2)
                     FROM zamaraeva_food.review r
                    WHERE r.entity_type = 'блюдо'
                      AND r.entity_id   = OLD.entity_id
               )
             WHERE product_id = OLD.entity_id;

        ELSIF OLD.entity_type = 'ресторан' THEN
            UPDATE zamaraeva_food.restaurant
               SET rating = (
                   SELECT round(avg(r.rating), 2)
                     FROM zamaraeva_food.review r
                    WHERE r.entity_type = 'ресторан'
                      AND r.entity_id   = OLD.entity_id
               )
             WHERE restaurant_id = OLD.entity_id;
        END IF;
    END IF;

    IF TG_OP = 'INSERT' OR (
        TG_OP = 'UPDATE' AND (NEW.entity_type != OLD.entity_type OR NEW.entity_id != OLD.entity_id)
    ) THEN
        IF NEW.entity_type = 'блюдо' THEN
            UPDATE zamaraeva_food.product
               SET rating = (
                   SELECT round(avg(r.rating), 2)
                     FROM zamaraeva_food.review r
                    WHERE r.entity_type = 'блюдо'
                      AND r.entity_id   = NEW.entity_id
               )
             WHERE product_id = NEW.entity_id;

        ELSIF NEW.entity_type = 'ресторан' THEN
            UPDATE zamaraeva_food.restaurant
               SET rating = (
                   SELECT round(avg(r.rating), 2)
                     FROM zamaraeva_food.review r
                    WHERE r.entity_type = 'ресторан'
                      AND r.entity_id   = NEW.entity_id
               )
             WHERE restaurant_id = NEW.entity_id;
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_review_rating_change ON zamaraeva_food.review;

CREATE TRIGGER trg_review_rating_change
AFTER INSERT OR UPDATE OR DELETE ON zamaraeva_food.review
FOR EACH ROW
EXECUTE FUNCTION zamaraeva_food.rating_change();