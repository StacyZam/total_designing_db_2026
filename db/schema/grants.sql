-- FOOD-109: Создание роли inspector и выдача прав
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'inspector') THEN
        CREATE ROLE inspector WITH LOGIN PASSWORD 'NetoSQL2025';
    ELSE
        ALTER ROLE inspector WITH LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END
$$;

GRANT ALL PRIVILEGES ON SCHEMA zamaraeva_food TO inspector;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA zamaraeva_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA zamaraeva_food TO inspector;
GRANT ALL PRIVILEGES ON ALL ROUTINES  IN SCHEMA zamaraeva_food TO inspector;

ALTER DEFAULT PRIVILEGES IN SCHEMA zamaraeva_food GRANT ALL PRIVILEGES ON TABLES    TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA zamaraeva_food GRANT ALL PRIVILEGES ON SEQUENCES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA zamaraeva_food GRANT ALL PRIVILEGES ON ROUTINES  TO inspector;

GRANT USAGE ON SCHEMA exts TO inspector;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exts TO inspector;

GRANT USAGE ON SCHEMA information_schema TO inspector;
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO inspector;
GRANT USAGE ON SCHEMA pg_catalog TO inspector;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO inspector;

-- Запрет на смену пароля пользователя
REVOKE UPDATE ON zamaraeva_food.client FROM PUBLIC;
-- Разрешаем обновлять только логин и телефон, но не пароль
GRANT UPDATE (login, phone_number) ON zamaraeva_food.client TO inspector;
