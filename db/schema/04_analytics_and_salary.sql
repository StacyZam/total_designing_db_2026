-- FOOD-106: Функция статистики по ресторанам get_statistic()
CREATE OR REPLACE FUNCTION zamaraeva_food.get_statistic()
RETURNS TABLE (
    restaurant_name   varchar,
    best_product_name varchar,
    total_amount      numeric,
    avg_amount        numeric,
    best_user         varchar
)
LANGUAGE sql
STABLE
AS $$
    WITH delivered_orders AS (
        SELECT o.order_id,
               o.restaurant_id,
               o.client_id,
               o.total_amount
          FROM zamaraeva_food."order" o
         WHERE o.status = 'доставлен'
    ),
    order_stats AS (
        SELECT d.restaurant_id,
               round(sum(d.total_amount), 2) AS total_amount,
               round(avg(d.total_amount), 2) AS avg_amount
          FROM delivered_orders d
         GROUP BY d.restaurant_id
    ),
    product_totals AS (
        SELECT d.restaurant_id,
               os.product_id,
               sum(os.quantity) AS sum_qty
          FROM delivered_orders d
          JOIN zamaraeva_food.order_structure os ON os.order_id = d.order_id
         GROUP BY d.restaurant_id, os.product_id
    ),
    best_products AS (
        SELECT DISTINCT ON (pt.restaurant_id)
               pt.restaurant_id,
               p.product_name AS best_product_name
          FROM product_totals pt
          JOIN zamaraeva_food.product p ON p.product_id = pt.product_id
         ORDER BY pt.restaurant_id, pt.sum_qty DESC, pt.product_id
    ),
    client_totals AS (
        SELECT d.restaurant_id,
               d.client_id,
               count(d.order_id) AS cnt_orders
          FROM delivered_orders d
         GROUP BY d.restaurant_id, d.client_id
    ),
    best_clients AS (
        SELECT DISTINCT ON (ct.restaurant_id)
               ct.restaurant_id,
               c.login AS best_user
          FROM client_totals ct
          JOIN zamaraeva_food.client c ON c.client_id = ct.client_id
         ORDER BY ct.restaurant_id, ct.cnt_orders DESC, ct.client_id
    )
    SELECT r.restaurant_name,
           bp.best_product_name,
           coalesce(ost.total_amount, 0::numeric) AS total_amount,
           coalesce(ost.avg_amount, 0::numeric)   AS avg_amount,
           bc.best_user
      FROM zamaraeva_food.restaurant r
      LEFT JOIN order_stats   ost ON ost.restaurant_id = r.restaurant_id
      LEFT JOIN best_products bp  ON bp.restaurant_id  = r.restaurant_id
      LEFT JOIN best_clients  bc  ON bc.restaurant_id  = r.restaurant_id
     ORDER BY r.restaurant_name;
$$;

-- FOOD-107: Процедура расчёта зарплаты курьеров courier_salary()
CREATE OR REPLACE PROCEDURE zamaraeva_food.courier_salary()
LANGUAGE plpgsql
AS $$
DECLARE
    v_year  int := extract(year  FROM current_date)::int;
    v_month int := extract(month FROM current_date)::int;
BEGIN
    WITH courier_monthly_agg AS (
        SELECT c.courier_id,
               c.status,
               c.coefficient AS current_coeff,
               count(o.order_id) AS delivered_cnt,
               coalesce(sum(o.commission), 0)::numeric(12, 2) AS commission_sum
          FROM zamaraeva_food.courier c
          LEFT JOIN zamaraeva_food."order" o
            ON o.courier_id = c.courier_id
           AND o.status = 'доставлен'
           AND extract(year  FROM o.order_timestamp) = v_year
           AND extract(month FROM o.order_timestamp) = v_month
         GROUP BY c.courier_id, c.status, c.coefficient
    ),
    calculated_salary AS (
        SELECT cma.courier_id,
               cma.status,
               cma.current_coeff,
               round(cma.current_coeff * cma.commission_sum, 2) AS salary_amount,
               CASE
                   WHEN cma.delivered_cnt <= 150 THEN 0.1
                   WHEN cma.delivered_cnt <= 250 THEN 0.2
                   WHEN cma.delivered_cnt <= 500 THEN 0.3
                   ELSE 0.5
               END::numeric(2, 1) AS new_coeff
          FROM courier_monthly_agg cma
    ),
    upsert_pay AS (
        INSERT INTO zamaraeva_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        SELECT v_year,
               v_month,
               cs.courier_id,
               cs.salary_amount,
               cs.current_coeff
          FROM calculated_salary cs
        ON CONFLICT (year, month, courier_id) DO UPDATE
            SET amount           = EXCLUDED.amount,
                coefficient_used = EXCLUDED.coefficient_used
        RETURNING courier_id
    )
    UPDATE zamaraeva_food.courier c
       SET coefficient = cs.new_coeff
      FROM calculated_salary cs
     WHERE c.courier_id = cs.courier_id
       AND c.status != 'уволен';
END;
$$;

-- FOOD-108: Представление how_much_money
CREATE OR REPLACE VIEW zamaraeva_food.how_much_money AS
WITH RECURSIVE bounds AS (
    SELECT date_trunc('month', min(o.order_timestamp))::date AS min_month,
           date_trunc('month', max(o.order_timestamp))::date AS max_month
      FROM zamaraeva_food."order" o
     WHERE o.status = 'доставлен'
),
months_series AS (
    SELECT b.min_month AS month_date,
           b.max_month
      FROM bounds b
     WHERE b.min_month IS NOT NULL
    UNION ALL
    SELECT (ms.month_date + interval '1 month')::date AS month_date,
           ms.max_month
      FROM months_series ms
     WHERE ms.month_date < ms.max_month
),
monthly_orders AS (
    SELECT date_trunc('month', o.order_timestamp)::date AS month_date,
           round(sum(o.order_amount), 2) AS sum_no_commission,
           round(sum(o.total_amount), 2) AS sum_with_commission
      FROM zamaraeva_food."order" o
     WHERE o.status = 'доставлен'
     GROUP BY date_trunc('month', o.order_timestamp)::date
),
monthly_courier_pay AS (
    SELECT make_date(cp.year, cp.month, 1) AS month_date,
           round(sum(cp.amount), 2) AS courier_pay
      FROM zamaraeva_food.courier_pay cp
     GROUP BY make_date(cp.year, cp.month, 1)
),
combined AS (
    SELECT to_char(ms.month_date, 'YYYY-MM')::text AS year_month,
           coalesce(mo.sum_no_commission, 0)::numeric   AS sum_no_commission,
           coalesce(mo.sum_with_commission, 0)::numeric AS sum_with_commission,
           (coalesce(mo.sum_with_commission, 0) - coalesce(mo.sum_no_commission, 0))::numeric AS commission,
           coalesce(mcp.courier_pay, 0)::numeric        AS courier_pay
      FROM months_series ms
      LEFT JOIN monthly_orders      mo  ON mo.month_date  = ms.month_date
      LEFT JOIN monthly_courier_pay mcp ON mcp.month_date = ms.month_date
)
SELECT c.year_month,
       c.sum_no_commission,
       c.sum_with_commission,
       c.commission,
       lag(c.commission) OVER (ORDER BY c.year_month)::numeric AS prev_commission,
       (c.commission - lag(c.commission) OVER (ORDER BY c.year_month))::numeric AS commission_diff,
       c.courier_pay,
       (c.commission - c.courier_pay)::numeric AS net_profit
  FROM combined c
 ORDER BY c.year_month;