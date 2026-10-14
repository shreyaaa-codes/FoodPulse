"""Reads orders from Redpanda.
 - raw JSON  -> MongoDB (raw_orders)
 - same JSON -> PostgreSQL staging table (stg_orders)
Run:  python consumer.py
"""
import json

import psycopg2
from kafka import KafkaConsumer
from pymongo import MongoClient

from config import KAFKA_BROKER, MONGO_URI, PG_DSN, TOPIC

consumer = KafkaConsumer(
    TOPIC,
    bootstrap_servers=KAFKA_BROKER,
    group_id="order-consumer",
    auto_offset_reset="earliest",
    value_deserializer=lambda m: json.loads(m.decode("utf-8")),
)
raw = MongoClient(MONGO_URI)["food_delivery"]["raw_orders"]
conn = psycopg2.connect(PG_DSN)
conn.autocommit = True
cur = conn.cursor()

print("Consumer started, waiting for orders... (Ctrl+C to stop)")
count = 0
for msg in consumer:
    order = msg.value
    raw.insert_one(dict(order))      # copy, because Mongo adds an _id field
    cur.execute(
        "INSERT INTO stg_orders (order_id, payload) VALUES (%s, %s)",
        (order.get("order_id"), json.dumps(order)),
    )
    count += 1
    if count % 50 == 0:
        print(f"{count} orders stored")
