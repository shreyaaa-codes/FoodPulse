import sys
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator

sys.path.insert(0, "/opt/airflow/project")
from etl import quality_report, run  # noqa: E402

with DAG(
    dag_id="food_delivery_etl",
    start_date=datetime(2026, 10, 1),
    schedule="*/15 * * * *",          # every 15 minutes
    catchup=False,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=1)},
    tags=["food-delivery"],
) as dag:
    etl_task = PythonOperator(task_id="validate_clean_load", python_callable=run)
    quality_task = PythonOperator(task_id="data_quality_report", python_callable=quality_report)
    etl_task >> quality_task
