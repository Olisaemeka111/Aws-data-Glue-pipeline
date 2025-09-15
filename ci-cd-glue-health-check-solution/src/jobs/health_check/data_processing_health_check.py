#!/usr/bin/env python3
"""AWS Glue ETL Job with Health Check Capabilities"""

import sys
from datetime import datetime
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import current_timestamp
from pyspark.sql.types import StructType, StructField, StringType, TimestampType
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'health-check-mode', 'dry-run'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

def is_health_check_mode():
    return args.get('health-check-mode', 'false').lower() == 'true'

def create_stub_data():
    if is_health_check_mode():
        logger.info("🧪 Creating stub data...")
        test_data = [("test_1", "value_1", datetime.now())]
        schema = StructType([
            StructField("id", StringType(), True),
            StructField("value", StringType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        df = spark.createDataFrame(test_data, schema)
        return DynamicFrame.fromDF(df, glueContext, "stub_data")
    else:
        return glueContext.create_dynamic_frame.from_catalog(
            database="your_database", table_name="your_table"
        )

def main():
    try:
        logger.info(f"🚀 Starting job: {args['JOB_NAME']}")
        if is_health_check_mode():
            logger.info("🧪 HEALTH CHECK MODE")
        
        source_data = create_stub_data()
        df = source_data.toDF().withColumn("processed_at", current_timestamp())
        
        if df.count() == 0:
            raise Exception("Empty dataset")
        
        logger.info(f"✅ Processed {df.count()} records successfully!")
        
    except Exception as e:
        logger.error(f"❌ Job failed: {e}")
        raise
    finally:
        job.commit()

if __name__ == "__main__":
    main()
