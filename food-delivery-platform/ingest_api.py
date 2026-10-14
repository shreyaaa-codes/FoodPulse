"""FastAPI ingestion layer: receives an order, checks its shape, pushes it to Redpanda.
Run:  uvicorn ingest_api:app --reload   (docs at http://localhost:8000/docs)
"""
import json
from datetime import datetime
from typing import Optional

from fastapi import FastAPI
from kafka import KafkaProducer
from pydantic import BaseModel

from config import KAFKA_BROKER, TOPIC

app = FastAPI(title="Food Delivery Ingestion API")
_producer = None


def get_producer():
    global _producer
    if _producer is None:
        _producer = KafkaProducer(
            bootstrap_servers=KAFKA_BROKER,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        )
    return _producer


class Order(BaseModel):
    # The API only checks structure/types (bad JSON -> 422).
    # Business rules (price > 0, duplicates...) are checked later in the ETL.
    order_id: str
    customer_id: Optional[str] = None
    customer_name: Optional[str] = None
    customer_city: Optional[str] = None
    restaurant_id: Optional[str] = None
    restaurant_name: Optional[str] = None
    cuisine: Optional[str] = None
    item_name: Optional[str] = None
    quantity: int
    unit_price: float
    payment_method: Optional[str] = "UPI"
    status: Optional[str] = "DELIVERED"
    order_time: datetime


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/orders", status_code=202)
def create_order(order: Order):
    get_producer().send(TOPIC, order.model_dump(mode="json"))
    return {"status": "queued", "order_id": order.order_id}
