"""Validate -> clean -> load staging orders into the PostgreSQL star schema.
Run manually:  python etl.py        (Airflow runs it on a schedule)
Logs:  logs/etl.log (everything)   logs/errors.log (rejected orders only)
"""
import json
import logging
import os
from datetime import datetime, timedelta

import psycopg2

from config import PG_DSN

LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
log = logging.getLogger("etl")
log.setLevel(logging.INFO)
if not log.handlers:
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    console = logging.StreamHandler()
    console.setFormatter(fmt)
    log.addHandler(console)
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        all_log = logging.FileHandler(os.path.join(LOG_DIR, "etl.log"))
        err_log = logging.FileHandler(os.path.join(LOG_DIR, "errors.log"))
        err_log.setLevel(logging.WARNING)
        for h in (all_log, err_log):
            h.setFormatter(fmt)
            log.addHandler(h)
    except OSError:
        pass  # e.g. read-only folder: console logging only

VALID_STATUS = {"DELIVERED", "CANCELLED", "PLACED"}


def clean_and_validate(o):
    """Returns (cleaned_dict, errors). If errors is non-empty the order is rejected."""
    errors = []
    for f in ("order_id", "customer_id", "restaurant_id", "item_name", "order_time"):
        if not o.get(f):
            errors.append(f"missing {f}")

    try:
        qty = int(o.get("quantity"))
        price = float(o.get("unit_price"))
    except (TypeError, ValueError):
        return None, errors + ["quantity/price not numeric"]
    if qty <= 0:
        errors.append("quantity must be > 0")
    if price <= 0 or price > 5000:
        errors.append("unit_price out of range")

    ts = None
    try:
        ts = datetime.fromisoformat(str(o.get("order_time"))).replace(tzinfo=None)
        if ts > datetime.now() + timedelta(minutes=5):
            errors.append("order_time in the future")
    except ValueError:
        errors.append("invalid order_time")

    status = str(o.get("status") or "").strip().upper()
    if status not in VALID_STATUS:
        errors.append(f"invalid status '{status}'")

    if errors:
        return None, errors

    t = lambda v: v.strip().title() if v else None   # clean text: trim + Title Case
    return {
        "order_id": str(o["order_id"]).strip(),
        "customer_id": str(o["customer_id"]).strip(),
        "customer_name": t(o.get("customer_name")),
        "customer_city": t(o.get("customer_city")),
        "restaurant_id": str(o["restaurant_id"]).strip(),
        "restaurant_name": t(o.get("restaurant_name")),
        "cuisine": t(o.get("cuisine")),
        "item_name": t(o["item_name"]),
        "quantity": qty,
        "unit_price": round(price, 2),
        "total_amount": round(qty * price, 2),
        "status": status,
        "payment_method": (o.get("payment_method") or "UNKNOWN").strip().upper(),
        "ts": ts,
    }, []


def upsert_time(cur, ts):
    key = int(ts.strftime("%Y%m%d"))
    cur.execute(
        """INSERT INTO dim_time (time_key, full_date, day, month, month_name, quarter, year, weekday, is_weekend)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT (time_key) DO NOTHING""",
        (key, ts.date(), ts.day, ts.month, ts.strftime("%B"), (ts.month - 1) // 3 + 1,
         ts.year, ts.strftime("%A"), ts.weekday() >= 5),
    )
    return key


def load(cur, c):
    cur.execute(
        """INSERT INTO dim_customer (customer_id, name, city) VALUES (%s,%s,%s)
           ON CONFLICT (customer_id) DO UPDATE
           SET name = COALESCE(EXCLUDED.name, dim_customer.name),
               city = COALESCE(EXCLUDED.city, dim_customer.city)
           RETURNING customer_key""",
        (c["customer_id"], c["customer_name"], c["customer_city"]),
    )
    ckey = cur.fetchone()[0]
    cur.execute(
        """INSERT INTO dim_restaurant (restaurant_id, name, cuisine, city) VALUES (%s,%s,%s,%s)
           ON CONFLICT (restaurant_id) DO UPDATE
           SET name = COALESCE(EXCLUDED.name, dim_restaurant.name),
               cuisine = COALESCE(EXCLUDED.cuisine, dim_restaurant.cuisine)
           RETURNING restaurant_key""",
        (c["restaurant_id"], c["restaurant_name"], c["cuisine"], c["customer_city"]),
    )
    rkey = cur.fetchone()[0]
    tkey = upsert_time(cur, c["ts"])
    cur.execute(
        """INSERT INTO fact_orders (order_id, customer_key, restaurant_key, time_key, order_hour,
                                    item_name, quantity, unit_price, total_amount, status, payment_method)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
        (c["order_id"], ckey, rkey, tkey, c["ts"].hour, c["item_name"], c["quantity"],
         c["unit_price"], c["total_amount"], c["status"], c["payment_method"]),
    )


def run():
    conn = psycopg2.connect(PG_DSN)
    ok = bad = 0
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT id, order_id, payload FROM stg_orders WHERE processed = FALSE ORDER BY id")
            rows = cur.fetchall()
            log.info("ETL started: %d staged orders to process", len(rows))
            for sid, oid, payload in rows:
                cleaned, errors = clean_and_validate(payload)
                if cleaned:
                    cur.execute("SELECT 1 FROM fact_orders WHERE order_id = %s", (cleaned["order_id"],))
                    if cur.fetchone():
                        errors.append("duplicate order_id")
                if errors:
                    reason = "; ".join(errors)
                    cur.execute("INSERT INTO rejected_orders (order_id, payload, reason) VALUES (%s,%s,%s)",
                                (oid, json.dumps(payload), reason))
                    log.warning("REJECTED %s: %s", oid, reason)
                    bad += 1
                else:
                    load(cur, cleaned)
                    ok += 1
                cur.execute("UPDATE stg_orders SET processed = TRUE WHERE id = %s", (sid,))
    finally:
        conn.close()
    log.info("ETL finished: %d loaded, %d rejected", ok, bad)
    return {"loaded": ok, "rejected": bad}


def quality_report():
    conn = psycopg2.connect(PG_DSN)
    with conn, conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM fact_orders")
        good = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM rejected_orders")
        rejected = cur.fetchone()[0]
    conn.close()
    pct = 100.0 * rejected / max(good + rejected, 1)
    log.info("QUALITY: %d good, %d rejected (%.1f%% rejected)", good, rejected, pct)
    return pct


if __name__ == "__main__":
    run()
    quality_report()
