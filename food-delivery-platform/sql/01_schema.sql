-- STAGING: raw orders land here exactly as received
CREATE TABLE IF NOT EXISTS stg_orders (
    id           SERIAL PRIMARY KEY,
    order_id     TEXT,
    payload      JSONB NOT NULL,
    received_at  TIMESTAMP DEFAULT now(),
    processed    BOOLEAN DEFAULT FALSE
);

-- Orders that failed validation (with the reason)
CREATE TABLE IF NOT EXISTS rejected_orders (
    id          SERIAL PRIMARY KEY,
    order_id    TEXT,
    payload     JSONB,
    reason      TEXT,
    rejected_at TIMESTAMP DEFAULT now()
);

-- STAR SCHEMA
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_id  TEXT UNIQUE NOT NULL,
    name         TEXT,
    city         TEXT
);

CREATE TABLE IF NOT EXISTS dim_restaurant (
    restaurant_key SERIAL PRIMARY KEY,
    restaurant_id  TEXT UNIQUE NOT NULL,
    name           TEXT,
    cuisine        TEXT,
    city           TEXT
);

CREATE TABLE IF NOT EXISTS dim_time (
    time_key   INT PRIMARY KEY,          -- e.g. 20261010
    full_date  DATE UNIQUE,
    day        INT,
    month      INT,
    month_name TEXT,
    quarter    INT,
    year       INT,
    weekday    TEXT,
    is_weekend BOOLEAN
);

CREATE TABLE IF NOT EXISTS fact_orders (
    order_id       TEXT PRIMARY KEY,
    customer_key   INT REFERENCES dim_customer(customer_key),
    restaurant_key INT REFERENCES dim_restaurant(restaurant_key),
    time_key       INT REFERENCES dim_time(time_key),
    order_hour     INT,
    item_name      TEXT,
    quantity       INT,
    unit_price     NUMERIC(10,2),
    total_amount   NUMERIC(10,2),
    status         TEXT,
    payment_method TEXT
);

CREATE INDEX IF NOT EXISTS idx_fact_time     ON fact_orders(time_key);
CREATE INDEX IF NOT EXISTS idx_fact_customer ON fact_orders(customer_key);
CREATE INDEX IF NOT EXISTS idx_fact_rest     ON fact_orders(restaurant_key);
