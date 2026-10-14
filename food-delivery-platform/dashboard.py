"""Streamlit dashboard.  Run:  streamlit run dashboard.py"""
import pandas as pd
import streamlit as st
from sqlalchemy import create_engine, text

from config import SQLA_URL

st.set_page_config(page_title="Food Delivery Analytics", layout="wide")
engine = create_engine(SQLA_URL)


@st.cache_data(ttl=20)
def q(sql):
    with engine.connect() as c:
        return pd.read_sql(text(sql), c)


st.title("Food Delivery Analytics Platform")
if st.sidebar.button("Refresh data"):
    st.cache_data.clear()

kpi = q("SELECT COALESCE(SUM(total_amount),0)::float AS revenue, COUNT(*) AS orders "
        "FROM fact_orders WHERE status='DELIVERED'").iloc[0]
rep = q("SELECT COALESCE(repeat_pct,0)::float AS p FROM vw_repeat_customer_pct").iloc[0]["p"]
rej = int(q("SELECT COUNT(*) AS n FROM rejected_orders").iloc[0]["n"])

if int(kpi["orders"]) == 0:
    st.info("No data yet. Run generate_orders.py, consumer.py and etl.py first.")
    st.stop()

c1, c2, c3, c4 = st.columns(4)
c1.metric("Total revenue", f"₹{float(kpi['revenue']):,.0f}")
c2.metric("Delivered orders", f"{int(kpi['orders']):,}")
c3.metric("Repeat customers", f"{float(rep):.1f}%")
c4.metric("Rejected (bad data)", rej)

t1, t2, t3, t4, t5 = st.tabs(["Revenue", "Restaurants", "Busy hours", "OLAP (ROLLUP)", "Data quality"])

with t1:
    daily = q("SELECT full_date, revenue::float AS revenue FROM vw_daily_revenue ORDER BY full_date")
    st.subheader("Daily revenue")
    st.line_chart(daily.set_index("full_date")["revenue"])
    monthly = q("SELECT month_start, revenue::float AS revenue, growth_pct::float AS growth_pct "
                "FROM vw_monthly_growth ORDER BY month_start")
    st.subheader("Monthly revenue and growth %")
    left, right = st.columns(2)
    left.bar_chart(monthly.set_index("month_start")["revenue"])
    right.dataframe(monthly, use_container_width=True)

with t2:
    top = q("SELECT restaurant, city, cuisine, orders, revenue::float AS revenue "
            "FROM vw_top_restaurants ORDER BY revenue DESC")
    st.subheader("Top restaurants by revenue")
    st.bar_chart(top.set_index("restaurant")["revenue"])
    st.dataframe(top, use_container_width=True)
    dishes = q("SELECT item_name, SUM(quantity)::int AS sold FROM fact_orders "
               "WHERE status='DELIVERED' GROUP BY item_name ORDER BY sold DESC LIMIT 10")
    st.subheader("Best-selling dishes")
    st.bar_chart(dishes.set_index("item_name")["sold"])

with t3:
    hours = q("SELECT order_hour, orders FROM vw_orders_by_hour ORDER BY order_hour")
    st.subheader("Orders by hour of day")
    st.bar_chart(hours.set_index("order_hour")["orders"])

with t4:
    st.subheader("Revenue by city and cuisine with subtotals (ROLLUP)")
    roll = q("""SELECT COALESCE(r.city,'ALL CITIES') AS city,
                       COALESCE(r.cuisine,'ALL CUISINES') AS cuisine,
                       SUM(f.total_amount)::float AS revenue
                FROM fact_orders f JOIN dim_restaurant r USING (restaurant_key)
                WHERE f.status='DELIVERED'
                GROUP BY ROLLUP (r.city, r.cuisine)
                ORDER BY r.city, r.cuisine""")
    st.dataframe(roll, use_container_width=True)

with t5:
    st.subheader("Why orders were rejected")
    reasons = q("SELECT reason, COUNT(*) AS orders FROM rejected_orders GROUP BY reason ORDER BY orders DESC")
    st.bar_chart(reasons.set_index("reason")["orders"])
    st.dataframe(q("SELECT order_id, reason, rejected_at FROM rejected_orders ORDER BY id DESC LIMIT 50"),
                 use_container_width=True)
