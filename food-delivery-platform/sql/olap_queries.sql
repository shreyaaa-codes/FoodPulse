-- Run these manually in psql / pgAdmin (OLAP experiments)

-- 1) ROLLUP: subtotals year -> month -> cuisine
SELECT t.year, t.month_name, r.cuisine, SUM(f.total_amount) AS revenue
FROM fact_orders f
JOIN dim_time t USING (time_key)
JOIN dim_restaurant r USING (restaurant_key)
GROUP BY ROLLUP (t.year, t.month_name, r.cuisine)
ORDER BY t.year, t.month_name, r.cuisine;

-- 2) CUBE: every combination of city and cuisine
SELECT r.city, r.cuisine, SUM(f.total_amount) AS revenue
FROM fact_orders f
JOIN dim_restaurant r USING (restaurant_key)
GROUP BY CUBE (r.city, r.cuisine);

-- 3) GROUPING SETS
SELECT r.city, t.weekday, SUM(f.total_amount) AS revenue
FROM fact_orders f
JOIN dim_restaurant r USING (restaurant_key)
JOIN dim_time t USING (time_key)
GROUP BY GROUPING SETS ((r.city), (t.weekday), ());

-- 4) Window function: rank restaurants inside each city
SELECT city, name, revenue,
       DENSE_RANK() OVER (PARTITION BY city ORDER BY revenue DESC) AS rnk
FROM (
    SELECT r.city, r.name, SUM(f.total_amount) AS revenue
    FROM fact_orders f JOIN dim_restaurant r USING (restaurant_key)
    GROUP BY r.city, r.name
) x;

-- 5) Window function: days between a customer's orders (LAG)
SELECT c.customer_id, t.full_date,
       t.full_date - LAG(t.full_date) OVER (PARTITION BY c.customer_id ORDER BY t.full_date) AS days_since_last
FROM fact_orders f
JOIN dim_customer c USING (customer_key)
JOIN dim_time t USING (time_key);

-- 6) Query optimization: compare plans with and without the index
EXPLAIN ANALYZE SELECT * FROM fact_orders WHERE time_key = 20260901;
-- DROP INDEX idx_fact_time;   then run EXPLAIN ANALYZE again and compare
-- CREATE INDEX idx_fact_time ON fact_orders(time_key);
