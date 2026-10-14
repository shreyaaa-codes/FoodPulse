import os

PG_DSN = os.getenv("PG_DSN", "host=localhost port=5433 dbname=fooddb user=postgres password=postgres")
SQLA_URL = os.getenv("SQLA_URL", "postgresql+psycopg2://postgres:postgres@localhost:5433/fooddb")
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:19092")
TOPIC = "orders"
