"""Sends fake orders to the API.
  python generate_orders.py 600          -> 600 orders spread over the last 90 days (fills the dashboard)
  python generate_orders.py 10 --live    -> 10 orders stamped 'now', 1 per second (for the live demo)
About 6% are deliberately bad so the validation has something to catch.
"""
import random
import sys
import time
import uuid
from datetime import datetime, timedelta

import requests

API_URL = "http://localhost:8000/orders"
RESTAURANTS = [  # id, name, cuisine, city, menu
    ("R001", "Spice Garden", "North Indian", "Mumbai", [("Butter Chicken", 320), ("Paneer Tikka", 260), ("Dal Makhani", 220), ("Garlic Naan", 60)]),
    ("R002", "Dragon Wok", "Chinese", "Mumbai", [("Hakka Noodles", 190), ("Manchurian", 210), ("Fried Rice", 180)]),
    ("R003", "Pizza Palace", "Italian", "Mumbai", [("Margherita Pizza", 299), ("Pasta Alfredo", 280), ("Garlic Bread", 120)]),
    ("R004", "Dosa Corner", "South Indian", "Pune", [("Masala Dosa", 110), ("Idli Sambar", 80), ("Filter Coffee", 40)]),
    ("R005", "Biryani House", "Hyderabadi", "Pune", [("Chicken Biryani", 280), ("Veg Biryani", 220), ("Raita", 40)]),
    ("R006", "Burger Barn", "Fast Food", "Pune", [("Cheese Burger", 150), ("French Fries", 90), ("Chicken Wrap", 140)]),
    ("R007", "Tandoori Nights", "North Indian", "Thane", [("Tandoori Chicken", 340), ("Butter Naan", 55), ("Paneer Butter Masala", 250)]),
    ("R008", "Sushi Zen", "Japanese", "Thane", [("Veg Sushi Roll", 350), ("Miso Soup", 150), ("Ramen Bowl", 380)]),
]
FIRST = ["Aarav", "Riya", "Kabir", "Sneha", "Rohan", "Priya", "Arjun", "Neha", "Vikram", "Anjali", "Sahil", "Pooja"]
LAST = ["Sharma", "Patil", "Desai", "Mehta", "Iyer", "Khan", "Joshi", "Nair", "Singh", "Kulkarni"]
CITIES = ["Mumbai", "Pune", "Thane"]
BY_CITY = {c: [r for r in RESTAURANTS if r[3] == c] for c in CITIES}
CUSTOMERS = [(f"C{i:04d}", f"{random.choice(FIRST)} {random.choice(LAST)}", random.choice(CITIES)) for i in range(1, 401)]
HOURS = [8, 9, 12, 13, 13, 14, 16, 17, 19, 20, 20, 21, 21, 22]


def make_order(live):
    cid, cname, city = random.choice(CUSTOMERS)
    rid, rname, cuisine, _, menu = random.choice(BY_CITY[city])
    item, price = random.choice(menu)
    now = datetime.now()
    if live:
        when = now
    else:
        when = (now - timedelta(days=random.randint(0, 89))).replace(
            hour=random.choice(HOURS), minute=random.randint(0, 59), second=0, microsecond=0)
        if when > now:
            when -= timedelta(days=1)
    # slightly messy text on purpose, so the ETL cleaning step has work to do
    if random.random() < 0.1:
        cname, city = f"  {cname.lower()} ", city.upper()
    return {
        "order_id": "ORD" + uuid.uuid4().hex[:10].upper(),
        "customer_id": cid, "customer_name": cname, "customer_city": city,
        "restaurant_id": rid, "restaurant_name": rname, "cuisine": cuisine,
        "item_name": item, "quantity": random.randint(1, 4), "unit_price": float(price),
        "payment_method": random.choice(["UPI", "UPI", "CARD", "COD"]),
        "status": random.choices(["DELIVERED", "CANCELLED", "PLACED"], weights=[90, 7, 3])[0],
        "order_time": when.isoformat(timespec="seconds"),
    }


def corrupt(o):
    kind = random.choice(["neg_price", "no_customer", "zero_qty"])
    if kind == "neg_price":
        o["unit_price"] = -abs(o["unit_price"])
    elif kind == "no_customer":
        o["customer_id"] = None
    else:
        o["quantity"] = 0
    return o


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 600
    live = "--live" in sys.argv
    sent = []
    for i in range(1, n + 1):
        r = random.random()
        if r < 0.02 and sent:
            order = dict(random.choice(sent))          # duplicate order
        else:
            order = make_order(live)
            sent.append(order)
            if r < 0.06:
                order = corrupt(dict(order))           # invalid order
        try:
            requests.post(API_URL, json=order, timeout=5).raise_for_status()
        except Exception as e:
            print("Failed:", e)
            break
        if live:
            print(f"Sent {order['order_id']} ({order['item_name']})")
            time.sleep(1)
        elif i % 100 == 0:
            print(f"{i}/{n} sent")
    print("Done.")


if __name__ == "__main__":
    main()
