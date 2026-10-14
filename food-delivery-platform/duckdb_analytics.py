"""Export the warehouse to Parquet and query it with DuckDB (columnar / OLAP style).
Run:  python duckdb_analytics.py
"""
import os
import time

import duckdb
import pandas as pd
from sqlalchemy import create_engine, text

from config import SQLA_URL

os.makedirs("exports", exist_ok=True)
with create_engine(SQLA_URL).connect() as c:
    df = pd.read_sql(text("""
        SELECT f.*, t.full_date, t.month_name, t.weekday, r.cuisine, r.city
        FROM fact_orders f
        JOIN dim_time t USING (time_key)
        JOIN dim_restaurant r USING (restaurant_key)"""), c)
df.to_parquet("exports/orders.parquet", index=False)
print(f"Exported {len(df)} rows to exports/orders.parquet")

start = time.time()
duckdb.sql("""
    SELECT city, cuisine, ROUND(SUM(total_amount), 2) AS revenue
    FROM 'exports/orders.parquet'
    WHERE status = 'DELIVERED'
    GROUP BY ROLLUP (city, cuisine)
    ORDER BY city, cuisine
""").show()
print(f"DuckDB query took {time.time() - start:.4f}s")
