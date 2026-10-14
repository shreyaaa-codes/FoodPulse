-- Reusable business metrics (Experiment 4)
CREATE OR REPLACE VIEW vw_daily_revenue AS
SELECT t.full_date,
       COUNT(*)            AS orders,
       SUM(f.total_amount) AS revenue
FROM fact_orders f
JOIN dim_time t USING (time_key)
WHERE f.status = 'DELIVERED'
GROUP BY t.full_date;

CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT make_date(t.year, t.month, 1) AS month_start,
       SUM(f.total_amount)           AS revenue
FROM fact_orders f
JOIN dim_time t USING (time_key)
WHERE f.status = 'DELIVERED'
GROUP BY t.year, t.month;

CREATE OR REPLACE VIEW vw_monthly_growth AS
SELECT month_start,
       revenue,
       LAG(revenue) OVER (ORDER BY month_start) AS prev_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month_start))
             / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0), 2) AS growth_pct
FROM vw_monthly_revenue;

CREATE OR REPLACE VIEW vw_repeat_customer_pct AS
WITH c AS (
    SELECT customer_key, COUNT(*) AS n FROM fact_orders GROUP BY customer_key
)
SELECT COUNT(*)                          AS total_customers,
       COUNT(*) FILTER (WHERE n > 1)     AS repeat_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE n > 1) / NULLIF(COUNT(*), 0), 2) AS repeat_pct
FROM c;

CREATE OR REPLACE VIEW vw_top_restaurants AS
SELECT r.name AS restaurant, r.city, r.cuisine,
       COUNT(*) AS orders, SUM(f.total_amount) AS revenue
FROM fact_orders f
JOIN dim_restaurant r USING (restaurant_key)
WHERE f.status = 'DELIVERED'
GROUP BY r.name, r.city, r.cuisine;

CREATE OR REPLACE VIEW vw_orders_by_hour AS
SELECT order_hour, COUNT(*) AS orders
FROM fact_orders
GROUP BY order_hour;
