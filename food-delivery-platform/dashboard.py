"""Streamlit dashboard. Run: streamlit run dashboard.py"""
import pandas as pd
import streamlit as st
from sqlalchemy import create_engine, text
from config import SQLA_URL

st.set_page_config(
    page_title="FoodPulse Analytics",
    page_icon="🍔",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .main { background-color: #f8f9fa; }
    .block-container { padding-top: 1rem; }
    .metric-card {
        background: white;
        padding: 20px;
        border-radius: 10px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        text-align: center;
    }
    h1 { color: #e63946; font-size: 2.2rem !important; }
    h2 { color: #457b9d; font-size: 1.4rem !important; }
    .stTabs [data-baseweb="tab"] {
        font-size: 15px;
        font-weight: 600;
        padding: 10px 20px;
    }
    .stTabs [aria-selected="true"] {
        background-color: #e63946;
        color: white;
        border-radius: 8px 8px 0 0;
    }
    .insight-box {
        background: #e8f4f8;
        border-left: 5px solid #457b9d;
        padding: 12px 16px;
        border-radius: 0 8px 8px 0;
        margin: 8px 0;
    }
</style>
""", unsafe_allow_html=True)

engine = create_engine(SQLA_URL)

@st.cache_data(ttl=20)
def q(sql):
    with engine.connect() as c:
        return pd.read_sql(text(sql), c)

# Sidebar
with st.sidebar:
    st.image("https://img.icons8.com/color/96/food-delivery.png", width=80)
    st.title("FoodPulse")
    st.markdown("**Mini Analytics Platform**")
    st.markdown("---")
    st.markdown("### 📌 Navigation")
    st.markdown("Use the tabs to explore metrics")
    st.markdown("---")
    if st.button("🔄 Refresh Data"):
        st.cache_data.clear()
    st.markdown("---")
    st.markdown("### 📅 Data Range")
    date_range = q("SELECT MIN(full_date) AS start, MAX(full_date) AS end FROM dim_time t JOIN fact_orders f USING(time_key)")
    st.markdown(f"**From:** {date_range['start'][0]}")
    st.markdown(f"**To:** {date_range['end'][0]}")

# Header
st.markdown("# 🍔 FoodPulse — Food Delivery Analytics Platform")
st.markdown("*Real-time business insights for smarter decisions*")
st.markdown("---")

# KPI Data
kpi = q("SELECT COALESCE(SUM(total_amount),0)::float AS revenue, COUNT(*) AS orders FROM fact_orders WHERE status='DELIVERED'").iloc[0]
rep = q("SELECT COALESCE(repeat_pct,0)::float AS p FROM vw_repeat_customer_pct").iloc[0]["p"]
rej = int(q("SELECT COUNT(*) AS n FROM rejected_orders").iloc[0]["n"])
avg_order = float(kpi['revenue']) / max(int(kpi['orders']), 1)

if int(kpi["orders"]) == 0:
    st.warning("⚠️ No data yet. Run the pipeline first.")
    st.stop()

# KPI Cards
st.markdown("### 📊 Key Performance Indicators")
c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("💰 Total Revenue", f"₹{float(kpi['revenue']):,.0f}", "Live")
c2.metric("📦 Delivered Orders", f"{int(kpi['orders']):,}", "Completed")
c3.metric("🔁 Repeat Customers", f"{float(rep):.1f}%", "Loyalty")
c4.metric("❌ Rejected Orders", f"{rej}", "Bad data")
c5.metric("💵 Avg Order Value", f"₹{avg_order:,.0f}", "Per order")

st.markdown("---")

# Tabs
t1, t2, t3, t4, t5 = st.tabs([
    "📈 Revenue", "🍽️ Restaurants", "⏰ Busy Hours",
    "📦 OLAP Analysis", "🛡️ Data Quality"
])

with t1:
    st.markdown("## 📈 Revenue Trends")
    daily = q("SELECT full_date, revenue::float AS revenue, orders FROM vw_daily_revenue ORDER BY full_date")

    col1, col2 = st.columns([2,1])
    with col1:
        st.markdown("#### Daily Revenue (₹)")
        st.line_chart(daily.set_index("full_date")["revenue"], height=300, use_container_width=True)
    with col2:
        st.markdown("#### Top 5 Revenue Days")
        st.dataframe(daily.nlargest(5, "revenue")[["full_date","revenue","orders"]].reset_index(drop=True), use_container_width=True)

    st.markdown("#### Monthly Revenue & Growth %")
    monthly = q("SELECT month_start, revenue::float AS revenue, COALESCE(growth_pct,0)::float AS growth_pct FROM vw_monthly_growth ORDER BY month_start")
    col3, col4 = st.columns(2)
    with col3:
        st.bar_chart(monthly.set_index("month_start")["revenue"], height=280)
    with col4:
        st.dataframe(monthly, use_container_width=True, height=280)

    st.markdown("""
    <div class='insight-box'>💡 <b>Insight:</b> August showed the highest monthly revenue with 57% growth over July. October shows a decline as month is incomplete.</div>
    """, unsafe_allow_html=True)

with t2:
    st.markdown("## 🍽️ Restaurant Performance")
    top = q("SELECT restaurant, city, cuisine, orders, revenue::float AS revenue FROM vw_top_restaurants ORDER BY revenue DESC")

    col1, col2 = st.columns(2)
    with col1:
        st.markdown("#### Top Restaurants by Revenue (₹)")
        st.bar_chart(top.head(10).set_index("restaurant")["revenue"], height=320)
    with col2:
        st.markdown("#### Top Restaurants by Orders")
        st.bar_chart(top.head(10).set_index("restaurant")["orders"], height=320)

    st.markdown("#### Full Restaurant Leaderboard")
    st.dataframe(top, use_container_width=True)

    dishes = q("SELECT item_name, SUM(quantity)::int AS sold FROM fact_orders WHERE status='DELIVERED' GROUP BY item_name ORDER BY sold DESC LIMIT 10")
    st.markdown("#### 🥘 Best-Selling Dishes")
    st.bar_chart(dishes.set_index("item_name")["sold"], height=280)

    st.markdown("""
    <div class='insight-box'>💡 <b>Insight:</b> Top restaurants consistently outperform by both revenue and order count, suggesting brand loyalty drives repeat business.</div>
    """, unsafe_allow_html=True)

with t3:
    st.markdown("## ⏰ Peak Ordering Hours")
    hours = q("SELECT order_hour, orders FROM vw_orders_by_hour ORDER BY order_hour")
    peak = hours.loc[hours['orders'].idxmax(), 'order_hour']

    col1, col2 = st.columns([3,1])
    with col1:
        st.markdown("#### Orders by Hour of Day")
        st.bar_chart(hours.set_index("order_hour")["orders"], height=350)
    with col2:
        st.markdown("#### Stats")
        st.metric("🔥 Peak Hour", f"{int(peak)}:00")
        st.metric("📊 Total Hours", "24")
        st.metric("📦 Max Orders/hr", f"{int(hours['orders'].max())}")

    st.markdown("""
    <div class='insight-box'>💡 <b>Insight:</b> Orders peak during lunch (12–2 PM) and dinner (7–9 PM) hours, suggesting staff and delivery resources should be maximised in these windows.</div>
    """, unsafe_allow_html=True)

with t4:
    st.markdown("## 📦 OLAP Multidimensional Analysis")

    st.markdown("#### ROLLUP — Revenue by City → Cuisine (with subtotals)")
    roll = q("""
        SELECT COALESCE(r.city,'ALL CITIES') AS city,
               COALESCE(r.cuisine,'ALL CUISINES') AS cuisine,
               SUM(f.total_amount)::float AS revenue
        FROM fact_orders f JOIN dim_restaurant r USING (restaurant_key)
        WHERE f.status='DELIVERED'
        GROUP BY ROLLUP (r.city, r.cuisine)
        ORDER BY r.city, r.cuisine
    """)
    st.dataframe(roll, use_container_width=True, height=300)

    st.markdown("#### CUBE — All combinations of City × Cuisine")
    cube = q("""
        SELECT COALESCE(r.city,'ALL CITIES') AS city,
               COALESCE(r.cuisine,'ALL CUISINES') AS cuisine,
               SUM(f.total_amount)::float AS revenue
        FROM fact_orders f JOIN dim_restaurant r USING (restaurant_key)
        WHERE f.status='DELIVERED'
        GROUP BY CUBE (r.city, r.cuisine)
        ORDER BY city, cuisine
    """)
    st.dataframe(cube, use_container_width=True, height=250)

    st.markdown("""
    <div class='insight-box'>💡 <b>Insight:</b> ROLLUP reveals city-level subtotals while CUBE gives every possible combination — useful for slice-and-dice analysis across dimensions.</div>
    """, unsafe_allow_html=True)

with t5:
    st.markdown("## 🛡️ Data Quality Report")
    col1, col2 = st.columns(2)
    with col1:
        st.metric("✅ Valid Orders Loaded", f"{int(kpi['orders']):,}")
        st.metric("❌ Rejected Orders", f"{rej}")
        st.metric("📊 Rejection Rate", f"{round(rej/(int(kpi['orders'])+rej)*100,1)}%")
    with col2:
        reasons = q("SELECT reason, COUNT(*) AS orders FROM rejected_orders GROUP BY reason ORDER BY orders DESC")
        if not reasons.empty:
            st.markdown("#### Rejection Reasons")
            st.bar_chart(reasons.set_index("reason")["orders"], height=200)

    st.markdown("#### Recent Rejected Orders")
    st.dataframe(q("SELECT order_id, reason, rejected_at FROM rejected_orders ORDER BY id DESC LIMIT 20"), use_container_width=True)

    st.markdown("""
    <div class='insight-box'>💡 <b>Insight:</b> Data quality checks caught invalid orders before they reached the warehouse, ensuring all KPI calculations are based on clean, validated data only.</div>
    """, unsafe_allow_html=True)

st.markdown("---")
st.markdown("<center><small>FoodPulse Analytics Platform • Data Engineering Mini Project • 2026</small></center>", unsafe_allow_html=True)