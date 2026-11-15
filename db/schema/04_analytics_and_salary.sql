-- FOOD-106: Функция статистики по ресторанам get_statistic()
CREATE OR REPLACE FUNCTION zamaraeva_food.get_statistic()
RETURNS TABLE (
    restaurant_name   VARCHAR,
    best_product_name VARCHAR,
    total_amount      NUMERIC,
    avg_amount        NUMERIC,
    best_user         VARCHAR
)
LANGUAGE sql
AS $$
    WITH delivered_orders AS (
        SELECT 
			o.order_id, 
			o.restaurant_id, 
			o.client_id, 
			o.total_amount
        FROM zamaraeva_food."order" o
        WHERE o.status = 'доставлен'
    ),
    order_stats AS (
        SELECT restaurant_id,
               SUM(total_amount) AS total_amount,
               AVG(total_amount) AS avg_amount
			FROM delivered_orders
        GROUP BY restaurant_id
    ),
    product_totals AS (
        SELECT 
				d.restaurant_id, 
				p.product_name, 
				SUM(os.quantity) AS sum_qty
			FROM delivered_orders d
			JOIN zamaraeva_food.order_structure os ON os.order_id = d.order_id
			JOIN zamaraeva_food.product p ON p.product_id = os.product_id
        GROUP BY d.restaurant_id, p.product_id, p.product_name
    ),
    best_products AS (
        SELECT DISTINCT ON (restaurant_id) 
				restaurant_id, 
				product_name
			FROM product_totals
        ORDER BY restaurant_id, sum_qty DESC, product_name
    ),
    client_totals AS (
        SELECT 
				d.restaurant_id, 
				c.login, 
				COUNT(*) AS cnt_orders
			FROM delivered_orders d
			JOIN zamaraeva_food.client c ON c.client_id = d.client_id
        GROUP BY d.restaurant_id, c.client_id, c.login
    ),
    best_clients AS (
        SELECT DISTINCT ON (restaurant_id) 
				restaurant_id, 
				login
			FROM client_totals ct
        ORDER BY ct.restaurant_id, ct.cnt_orders DESC, login
    )
    SELECT r.restaurant_name,
           bp.product_name,
           ost.total_amount,
           ost.avg_amount,
           bc.login
    FROM zamaraeva_food.restaurant r
    LEFT JOIN order_stats ost ON ost.restaurant_id = r.restaurant_id
    LEFT JOIN best_products bp ON bp.restaurant_id = r.restaurant_id
    LEFT JOIN best_clients bc ON bc.restaurant_id = r.restaurant_id;
$$;

-- FOOD-107: Процедура расчёта зарплаты курьеров courier_salary()
CREATE OR REPLACE PROCEDURE zamaraeva_food.courier_salary()
LANGUAGE plpgsql
AS $$
DECLARE
    v_month_start TIMESTAMP := DATE_TRUNC('month', CURRENT_TIMESTAMP);
    v_year        INTEGER   := EXTRACT(YEAR FROM v_month_start)::INTEGER;
    v_month       INTEGER   := EXTRACT(MONTH FROM v_month_start)::INTEGER;
BEGIN
    WITH month_orders AS (
        SELECT c.courier_id,
               c.status,
               COALESCE(cp.coefficient_used, c.coefficient) AS coeff_to_use,
               COUNT(o.order_id) AS deliv_cnt,
               COALESCE(SUM(o.commission), 0) AS total_comm
        FROM zamaraeva_food.courier c
        LEFT JOIN zamaraeva_food."order" o
          ON o.courier_id = c.courier_id
         AND o.status = 'доставлен'
         AND o.order_timestamp >= v_month_start
         AND o.order_timestamp < v_month_start + INTERVAL '1 month'
        LEFT JOIN zamaraeva_food.courier_pay cp
          ON cp.courier_id = c.courier_id
         AND cp.year = v_year
         AND cp.month = v_month
        GROUP BY c.courier_id, c.status, c.coefficient, cp.coefficient_used
    ),
    upsert_pay AS (
        INSERT INTO zamaraeva_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        SELECT v_year,
               v_month,
               courier_id,
               ROUND(coeff_to_use * total_comm, 2),
               coeff_to_use
        FROM month_orders
        ON CONFLICT (year, month, courier_id)
        DO UPDATE SET amount = EXCLUDED.amount,
                      coefficient_used = EXCLUDED.coefficient_used
    )
    UPDATE zamaraeva_food.courier c
    SET coefficient = CASE
        WHEN mo.deliv_cnt <= 150 THEN 0.1
        WHEN mo.deliv_cnt <= 250 THEN 0.2
        WHEN mo.deliv_cnt <= 500 THEN 0.3
        ELSE 0.5
    END
    FROM month_orders mo
    WHERE c.courier_id = mo.courier_id
      AND c.status <> 'уволен';
END;
$$;

-- FOOD-108: Представление how_much_money
CREATE OR REPLACE VIEW zamaraeva_food.how_much_money AS
WITH monthly_orders AS (
    SELECT DATE_TRUNC('month', order_timestamp)::DATE AS month_date,
           SUM(order_amount) AS sum_no_commission,
           SUM(total_amount) AS sum_with_commission
    FROM zamaraeva_food."order"
    WHERE status = 'доставлен'
    GROUP BY 1
),
bounds AS (
    SELECT MIN(month_date) AS min_month,
           MAX(month_date) AS max_month
    FROM monthly_orders
),
months_series AS (
    SELECT GENERATE_SERIES(b.min_month, b.max_month, INTERVAL '1 month')::DATE AS month_date
    FROM bounds b
    WHERE b.min_month IS NOT NULL
),
monthly_courier_pay AS (
    SELECT MAKE_DATE(year, month, 1) AS month_date,
           SUM(amount) AS courier_pay
    FROM zamaraeva_food.courier_pay
    GROUP BY 1
),
combined AS (
    SELECT ms.month_date,
           COALESCE(mo.sum_no_commission, 0)::NUMERIC AS sum_no_commission,
           COALESCE(mo.sum_with_commission, 0)::NUMERIC AS sum_with_commission,
           (COALESCE(mo.sum_with_commission, 0) - COALESCE(mo.sum_no_commission, 0))::NUMERIC AS commission,
           COALESCE(mcp.courier_pay, 0)::NUMERIC AS courier_pay
    FROM months_series ms
    LEFT JOIN monthly_orders mo ON mo.month_date = ms.month_date
    LEFT JOIN monthly_courier_pay mcp ON mcp.month_date = ms.month_date
)
SELECT TO_CHAR(month_date, 'YYYY-MM')::TEXT AS year_month,
       sum_no_commission,
       sum_with_commission,
       commission,
       LAG(commission) OVER (ORDER BY month_date) AS prev_commission,
       (commission - LAG(commission) OVER (ORDER BY month_date))::NUMERIC AS commission_diff,
       courier_pay,
       (commission - courier_pay)::NUMERIC AS net_profit
FROM combined
ORDER BY year_month;
