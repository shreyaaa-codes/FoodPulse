# FoodPulse — Food Delivery Analytics Platform

**Data Engineering Lab Mini Project**

FoodPulse is an end-to-end food delivery data engineering and analytics platform. It collects order data through a REST API, streams events using Redpanda, stores raw data in MongoDB, validates and transforms data into PostgreSQL, and presents business insights through an interactive Streamlit dashboard.

The project also demonstrates Apache Airflow orchestration, DuckDB analytics, Parquet exports, Delta Lake operations, and data quality monitoring.

## 1. Architecture

```text
Order Generator
      |
      v
FastAPI REST API
      |
      v
Redpanda (Kafka-compatible streaming)
      |
      v
Consumer
      |
      +--------------------+
      |                    |
      v                    v
MongoDB               PostgreSQL Staging
Raw JSON Orders             |
                            v
                     ETL Validation
                            |
                  +---------+---------+
                  |                   |
                  v                   v
          Rejected Orders       Clean Orders
                                      |
                                      v
                              PostgreSQL Warehouse
                              Fact + Dimension Tables
                                      |
                          +-----------+-----------+
                          |           |           |
                          v           v           v
                      SQL/OLAP     DuckDB      Dashboard
                                  + Parquet    Streamlit

Apache Airflow schedules and monitors ETL execution.
Delta Lake demonstrates versioning, updates, deletes,
schema validation, history, and time travel.
```

## 2. Technology Stack

- **Python** — data processing and orchestration scripts
- **FastAPI** — REST API for order ingestion
- **Redpanda** — Kafka-compatible event streaming
- **MongoDB** — raw JSON order storage
- **PostgreSQL** — staging tables and analytical warehouse
- **Apache Airflow** — scheduled ETL orchestration
- **Streamlit** — interactive analytics dashboard
- **DuckDB** — analytical queries over Parquet data
- **Parquet** — columnar data export
- **Delta Lake and PySpark** — transactional table operations and time travel
- **Docker Compose** — containerized services

## 3. Project Structure

```text
food-delivery-platform/
├── config.py
├── ingest_api.py
├── generate_orders.py
├── consumer.py
├── etl.py
├── dashboard.py
├── duckdb_analytics.py
├── delta_lake_demo.py
├── docker-compose.yml
├── requirements.txt
├── README.md
├── airflow_documentation.md
├── dags/
├── sql/
├── data/
├── exports/
├── artifacts/
├── backups/
└── logs/
```

## 4. Prerequisites

- Docker Desktop
- Python 3.10 or later, compatible with the project's dependencies
- Git (optional)

Start Docker Desktop before running the project.

## 5. Installation

Open a terminal in the project directory.

Create and activate a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install the dependencies:

```bash
pip install -r requirements.txt
```

Start the core services:

```bash
docker compose up -d postgres mongo redpanda
```

Check their status:

```bash
docker compose ps
```

PostgreSQL is exposed on host port `5433`, MongoDB on `27017`, and Redpanda on `19092`.

## 6. Running the End-to-End Pipeline

Run each long-running process in a separate terminal.

### Terminal 1: Start the REST API

```bash
source .venv/bin/activate
python -m uvicorn ingest_api:app --reload
```

API documentation:

http://localhost:8000/docs

Health check:

```bash
curl http://localhost:8000/health
```

### Terminal 2: Start the consumer

```bash
source .venv/bin/activate
python consumer.py
```

The consumer reads streaming orders and stores raw data in MongoDB and staging records in PostgreSQL.

### Terminal 3: Generate sample orders

```bash
source .venv/bin/activate
python generate_orders.py
```

The generator creates sample orders, including intentionally invalid records for data-quality testing.

Check `generate_orders.py` for its supported command-line arguments before passing a custom count or live mode.

### Terminal 4: Run the ETL pipeline

```bash
source .venv/bin/activate
python etl.py
```

The ETL pipeline:
1. Reads unprocessed staging records.
2. Validates required fields and business rules.
3. Cleans valid order data.
4. Rejects invalid or duplicate records.
5. Loads valid data into the PostgreSQL star schema.
6. Reports data-quality statistics.

ETL logs are stored in `logs/`, including rejected-order details.

### Terminal 5: Start the dashboard

```bash
source .venv/bin/activate
streamlit run dashboard.py
```

Dashboard:

http://localhost:8501

The dashboard includes:
- Revenue trends
- Restaurant performance
- Orders by hour
- OLAP ROLLUP analysis
- Data-quality rejection analysis

## 7. Apache Airflow

Start Airflow using the configured Compose profile:

```bash
docker compose --profile airflow up -d airflow
```

Open:

http://localhost:8080

Check the Airflow logs for the configured login credentials if required.

Enable the `food_delivery_etl` DAG to schedule the ETL and data-quality tasks.

See `airflow_documentation.md` for the DAG configuration, execution results, and screenshots.

## 8. DuckDB and Parquet Analytics

Run:

```bash
source .venv/bin/activate
python duckdb_analytics.py
```

The script exports warehouse data to Parquet and executes analytical queries using DuckDB.

Generated exports are stored in `exports/`.

## 9. Delta Lake Demonstration

The Delta Lake demonstration is implemented in `delta_lake_demo.py`.

It demonstrates:
- Creating a Delta table
- Inserting records
- Updating and deleting records
- Inspecting table history
- Reading an earlier table version through time travel
- Rejecting an incompatible schema append

Use the dedicated Delta Lake environment if one has been configured:

```bash
source .venv-delta/bin/activate
python delta_lake_demo.py
```

## 10. Data Quality

The ETL pipeline checks for issues such as:
- Missing required fields
- Invalid quantities
- Unit prices outside the permitted range
- Duplicate order IDs
- Invalid order statuses
- Invalid timestamps

Rejected records are stored in PostgreSQL and displayed in the dashboard's Data Quality tab.

The rejection rate is calculated as:

```text
Rejected records / (Loaded records + Rejected records) × 100
```

## 11. Database Backup

A PostgreSQL backup can be created with:

```bash
mkdir -p backups
docker compose exec -T postgres pg_dump -U postgres -d fooddb > backups/fooddb_backup.sql
```

Verify the backup:

```bash
ls -lh backups/fooddb_backup.sql
```

The backup contains database data and schema definitions. Keep it with the project submission if required by the lab instructions.

## 12. Lab Experiment Mapping

| Experiment | Implementation |
|---|---|
| 1 — EDA and cleaning | `etl.py`, `generate_orders.py` |
| 2 — Schema design and SQL | `sql/01_schema.sql` |
| 3 — ETL | `etl.py` |
| 4 — SQL views and metrics | `sql/02_views.sql` |
| 5 — OLAP and ROLLUP | `sql/olap_queries.sql`, dashboard |
| 6 — Dashboard | `dashboard.py` |
| 7 — MongoDB | `consumer.py` |
| 8 — Delta Lake | `delta_lake_demo.py` |
| 9 — REST API | `ingest_api.py` |
| 10 — Producer and consumer | `generate_orders.py`, `consumer.py` |
| 11 — DuckDB and Parquet | `duckdb_analytics.py` |
| 12 — Airflow | `dags/`, `airflow_documentation.md` |
| 13 — Data quality | `etl.py`, `rejected_orders`, dashboard |
| 14–15 — Integration | Complete end-to-end pipeline |

## 13. Viva Preparation

**Why use a star schema?**  
It separates measurable business events from descriptive dimensions, making analytical queries easier to understand and execute.

**Why use staging tables?**  
Staging provides an intermediate layer where incoming records can be validated before being loaded into the analytical warehouse.

**Why MongoDB and PostgreSQL?**  
MongoDB stores flexible raw JSON documents, while PostgreSQL stores structured relational data for analytics.

**Why Redpanda?**  
Redpanda provides Kafka-compatible event streaming and separates order ingestion from downstream processing.

**Why Airflow?**  
Airflow schedules, monitors, and records ETL workflow execution.

**Why DuckDB and Parquet?**  
DuckDB supports analytical queries, while Parquet provides a columnar format suitable for analytical workloads.

**Why Delta Lake?**  
Delta Lake supports transactional table operations, schema enforcement, version history, and time travel.

**How are invalid orders handled?**  
The ETL process validates records and stores rejected records with reasons for investigation.

## 14. Troubleshooting

- **API port already in use:** Check whether the API is already running before starting another instance.
- **Dashboard unavailable:** Start it with `streamlit run dashboard.py`.
- **Docker services unavailable:** Check `docker compose ps` and the service logs.
- **PostgreSQL connection failure:** Verify that PostgreSQL is running and that the connection settings in `config.py` match the Compose configuration.
- **Orders not appearing in the warehouse:** Check the consumer, staging table, and ETL logs.
- **Delta Lake errors:** Verify Java and the Python dependencies in the dedicated Delta Lake environment.

Avoid running `docker compose down -v` unless you deliberately want to remove the Compose volumes and understand the data-loss consequences.

---

**Project:** FoodPulse — Food Delivery Analytics Platform  
**Course:** Data Engineering Lab