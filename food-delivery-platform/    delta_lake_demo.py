import shutil
from pathlib import Path

from delta import configure_spark_with_delta_pip
from delta.tables import DeltaTable

from pyspark.sql import SparkSession
from pyspark.sql.functions import col


# --------------------------------------------------
# 1. PROJECT CONFIGURATION
# --------------------------------------------------

PROJECT_DIR = Path(__file__).resolve().parent

DELTA_PATH = PROJECT_DIR / "data" / "delta" / "experiment8_orders"

DELTA_PATH.parent.mkdir(parents=True, exist_ok=True)


# --------------------------------------------------
# 2. CREATE SPARK SESSION WITH DELTA LAKE
# --------------------------------------------------

builder = (
    SparkSession.builder
    .appName("FoodPulse-DeltaLake-Demo")
    .master("local[2]")
    .config(
        "spark.sql.extensions",
        "io.delta.sql.DeltaSparkSessionExtension"
    )
    .config(
        "spark.sql.catalog.spark_catalog",
        "org.apache.spark.sql.delta.catalog.DeltaCatalog"
    )
)

spark = configure_spark_with_delta_pip(builder).getOrCreate()

spark.sparkContext.setLogLevel("ERROR")


try:
    print("\n========== FOODPULSE DELTA LAKE DEMO ==========\n")

    # --------------------------------------------------
    # 3. CREATE SAMPLE DATA
    # --------------------------------------------------

    orders = [
        ("ORD1001", "C101", "Mumbai", 500.0, "PLACED"),
        ("ORD1002", "C102", "Pune", 750.0, "PLACED"),
        ("ORD1003", "C103", "Thane", 300.0, "PLACED"),
    ]

    columns = [
        "order_id",
        "customer_id",
        "city",
        "amount",
        "status"
    ]

    df = spark.createDataFrame(orders, columns)

    print("STEP 1: Initial sample data")
    df.show(truncate=False)

    # Start with a fresh demonstration table.
    # This removes only the previous Experiment 8 demo table.
    if DELTA_PATH.exists():
        shutil.rmtree(DELTA_PATH)

    # --------------------------------------------------
    # 4. CREATE DELTA TABLE
    # --------------------------------------------------

    df.write.format("delta").mode("overwrite").save(str(DELTA_PATH))

    delta_table = DeltaTable.forPath(spark, str(DELTA_PATH))

    print("STEP 2: Delta table created successfully")
    print("Delta table location:", DELTA_PATH)

    delta_table.toDF().show(truncate=False)

    # --------------------------------------------------
    # 5. INSERT A NEW ORDER
    # --------------------------------------------------

    new_order = [
        ("ORD1004", "C104", "Mumbai", 650.0, "PLACED")
    ]

    new_df = spark.createDataFrame(new_order, columns)

    new_df.write.format("delta").mode("append").save(str(DELTA_PATH))

    print("STEP 3: New order inserted")
    DeltaTable.forPath(spark, str(DELTA_PATH)).toDF().show(truncate=False)

    # --------------------------------------------------
    # 6. UPDATE AN ORDER
    # --------------------------------------------------

    delta_table = DeltaTable.forPath(spark, str(DELTA_PATH))

    delta_table.update(
        condition=col("order_id") == "ORD1002",
        set={
            "status": "'DELIVERED'",
            "amount": "800.0"
        }
    )

    print("STEP 4: Order ORD1002 updated")
    delta_table.toDF().show(truncate=False)

    # --------------------------------------------------
    # 7. DELETE AN ORDER
    # --------------------------------------------------

    delta_table.delete(
        condition=col("order_id") == "ORD1003"
    )

    print("STEP 5: Order ORD1003 deleted")
    delta_table.toDF().show(truncate=False)

    # --------------------------------------------------
    # 8. SHOW TABLE HISTORY
    # --------------------------------------------------

    print("STEP 6: Delta Lake table history")

    delta_table = DeltaTable.forPath(spark, str(DELTA_PATH))

    delta_table.history().select(
        "version",
        "timestamp",
        "operation"
    ).show(truncate=False)

    # --------------------------------------------------
    # 9. TIME TRAVEL
    # --------------------------------------------------

    print("STEP 7: Read original table using version 0")

    old_version = (
        spark.read
        .format("delta")
        .option("versionAsOf", 0)
        .load(str(DELTA_PATH))
    )

    old_version.show(truncate=False)

    print("Current version of the table")

    delta_table.toDF().show(truncate=False)

    # --------------------------------------------------
    # 10. TEST SCHEMA ENFORCEMENT
    # --------------------------------------------------

    print("STEP 8: Testing schema enforcement")

    wrong_schema_data = [
        ("ORD9999", "C999", "Mumbai", 999.0, "PLACED", "EXTRA_VALUE")
    ]

    wrong_schema_columns = columns + ["unexpected_column"]

    wrong_df = spark.createDataFrame(
        wrong_schema_data,
        wrong_schema_columns
    )

    try:
        (
            wrong_df.write
            .format("delta")
            .mode("append")
            .save(str(DELTA_PATH))
        )

        print("WARNING: The incompatible write was unexpectedly accepted.")

    except Exception as error:
        print("EXPECTED RESULT: Incompatible schema write was rejected.")
        print("Error type:", type(error).__name__)
        print("Error message:", str(error)[:500])

    print("\n========== DELTA LAKE DEMO FINISHED ==========\n")

finally:
    spark.stop()