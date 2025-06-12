import sys
import boto3
import time
from typing import Optional, Dict, Any
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from pyspark.sql.types import *
import datetime
import uuid
import json
import logging
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

class DataProcessingError(Exception):
    """Custom exception for data processing errors."""
    pass

def get_job_metadata() -> Dict[str, str]:
    """Get job metadata from job parameters."""
    try:
        args = getResolvedOptions(sys.argv, [
            'JOB_NAME', 
            'processed_bucket', 
            'curated_bucket', 
            'environment',
            'state_table',
            'database_name',
            'sns_topic_arn'
        ])
        return args
    except Exception as e:
        logger.error(f"Error parsing job arguments: {str(e)}")
        raise DataProcessingError(f"Failed to parse job arguments: {str(e)}")

def initialize_spark_context():
    """Initialize Spark and Glue contexts with optimized configuration."""
    try:
        sc = SparkContext()
        # Optimize Spark configuration for better performance
        sc.setLogLevel("WARN")
        
        glueContext = GlueContext(sc)
        spark = glueContext.spark_session
        
        # Set Spark SQL configurations for better performance
        spark.conf.set("spark.sql.adaptive.enabled", "true")
        spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
        spark.conf.set("spark.sql.parquet.enableVectorizedReader", "true")
        spark.conf.set("spark.sql.parquet.columnarReaderBatchSize", "4096")
        
        job = Job(glueContext)
        return sc, glueContext, spark, job
    except Exception as e:
        logger.error(f"Error initializing Spark context: {str(e)}")
        raise DataProcessingError(f"Failed to initialize Spark context: {str(e)}")

def update_job_state(dynamodb_client, table_name: str, job_name: str, status: str, 
                    message: Optional[str] = None, metadata: Optional[Dict[str, Any]] = None) -> None:
    """Update job state in DynamoDB with proper error handling."""
    try:
        item = {
            'job_name': {'S': job_name},
            'status': {'S': status},
            'updated_at': {'S': datetime.datetime.now().isoformat()},
            'environment': {'S': os.environ.get('ENVIRONMENT', 'unknown')}
        }
        
        if message:
            item['message'] = {'S': str(message)[:1000]}  # Limit message length
            
        if metadata:
            # Ensure metadata is serializable and limit size
            try:
                metadata_str = json.dumps(metadata, default=str)[:4000]  # DynamoDB attribute limit
                item['metadata'] = {'S': metadata_str}
            except (TypeError, ValueError) as e:
                logger.warning(f"Error serializing metadata: {str(e)}")
                item['metadata'] = {'S': '{"error": "metadata_serialization_failed"}'}
            
        dynamodb_client.put_item(
            TableName=table_name,
            Item=item
        )
        logger.info(f"Updated job state: {status}")
    except Exception as e:
        logger.error(f"Error updating job state: {str(e)}")
        # Don't raise exception to avoid breaking the main job flow

def send_notification(sns_client, topic_arn: str, subject: str, message: str) -> None:
    """Send SNS notification with error handling."""
    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject[:100],  # SNS subject limit
            Message=message[:262144]  # SNS message limit
        )
        logger.info(f"Notification sent: {subject}")
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")

def validate_data_schema(df, expected_columns: list) -> bool:
    """Validate that DataFrame has expected columns."""
    actual_columns = set(df.columns)
    expected_columns_set = set(expected_columns)
    
    missing_columns = expected_columns_set - actual_columns
    if missing_columns:
        logger.error(f"Missing required columns: {missing_columns}")
        return False
        
    logger.info("Schema validation passed")
    return True

def get_latest_processed_data(glueContext, processed_bucket: str, source_path: str) -> Optional[DynamicFrame]:
    """Get the latest processed data with improved error handling and validation."""
    try:
        full_path = f"s3://{processed_bucket}/{source_path}"
        logger.info(f"Reading data from {full_path}")
        
        # Check if path exists using S3 client
        s3_client = boto3.client('s3')
        try:
            response = s3_client.list_objects_v2(
                Bucket=processed_bucket,
                Prefix=source_path,
                MaxKeys=1
            )
            if response.get('KeyCount', 0) == 0:
                logger.warning(f"No objects found in {full_path}")
                return None
        except Exception as e:
            logger.error(f"Error checking S3 path existence: {str(e)}")
            return None
        
        # Read processed data in Parquet format with better options
        dynamic_frame = glueContext.create_dynamic_frame.from_options(
            connection_type="s3",
            connection_options={
                "paths": [full_path],
                "recurse": True,
                "optimizePerformance": True
            },
            format="parquet",
            format_options={
                "useThreads": True,
                "optimizePerformance": True
            }
        )
        
        record_count = dynamic_frame.count()
        if record_count == 0:
            logger.warning(f"No data found in {full_path}")
            return None
            
        logger.info(f"Successfully read {record_count} records from {full_path}")
        return dynamic_frame
        
    except Exception as e:
        logger.error(f"Error reading processed data: {str(e)}")
        raise DataProcessingError(f"Failed to read processed data: {str(e)}")

def apply_transformations(glueContext, dynamic_frame: DynamicFrame, environment: str) -> Optional[DynamicFrame]:
    """Apply comprehensive business transformations to the data."""
    if not dynamic_frame:
        return None
        
    try:
        # Convert to DataFrame for transformations
        df = dynamic_frame.toDF()
        initial_count = df.count()
        logger.info(f"Starting transformations on {initial_count} records")
        
        # Add processing metadata
        processing_id = str(uuid.uuid4())
        df = df.withColumn("processing_id", F.lit(processing_id))
        df = df.withColumn("processing_timestamp", F.current_timestamp())
        df = df.withColumn("processing_environment", F.lit(environment))
        
        # Data quality improvements
        # Handle null values intelligently based on column types
        for column in df.columns:
            column_type = df.schema[column].dataType
            if isinstance(column_type, (IntegerType, LongType, DoubleType, FloatType)):
                # Fill nulls in numeric columns with 0 or median based on business logic
                df = df.withColumn(column, F.when(F.col(column).isNull(), 0).otherwise(F.col(column)))
            elif isinstance(column_type, StringType):
                # Fill nulls in string columns with "Unknown" or empty string
                df = df.withColumn(column, F.when(F.col(column).isNull(), "Unknown").otherwise(F.col(column)))
        
        # Remove duplicate records based on business key (adjust as needed)
        if "id" in df.columns:
            df = df.dropDuplicates(["id"])
            
        # Add data validation flags
        df = df.withColumn("is_valid_record", F.lit(True))
        
        # Example business transformations (customize based on your requirements)
        if "amount" in df.columns:
            # Normalize amounts and add categories
            df = df.withColumn("normalized_amount", 
                             F.when(F.col("amount") > 0, F.col("amount")).otherwise(0))
            df = df.withColumn("amount_category",
                             F.when(F.col("amount") < 100, "Small")
                              .when(F.col("amount") < 1000, "Medium")
                              .otherwise("Large"))
        
        if "date" in df.columns:
            # Add date-based partitions and derived fields
            df = df.withColumn("year", F.year("date"))
            df = df.withColumn("month", F.month("date"))
            df = df.withColumn("day", F.dayofmonth("date"))
            df = df.withColumn("quarter", F.quarter("date"))
            df = df.withColumn("day_of_week", F.dayofweek("date"))
        else:
            # Use current date for partitioning if no date column exists
            current_date = datetime.datetime.now()
            df = df.withColumn("year", F.lit(current_date.year))
            df = df.withColumn("month", F.lit(current_date.month))
            df = df.withColumn("day", F.lit(current_date.day))
        
        # Add row-level lineage information
        df = df.withColumn("source_system", F.lit("glue_etl_pipeline"))
        df = df.withColumn("data_lineage", F.lit("processed_by_data_processing_job"))
        df = df.withColumn("data_version", F.lit("v1.0"))
        
        # Performance optimization: cache if data will be reused
        df.cache()
        
        final_count = df.count()
        logger.info(f"Transformation completed: {initial_count} -> {final_count} records")
        
        # Convert back to DynamicFrame
        processed_dynamic_frame = DynamicFrame.fromDF(df, glueContext, "processed_dynamic_frame")
        
        return processed_dynamic_frame
        
    except Exception as e:
        logger.error(f"Error applying transformations: {str(e)}")
        raise DataProcessingError(f"Failed to apply transformations: {str(e)}")

def write_curated_data(glueContext, dynamic_frame: DynamicFrame, curated_bucket: str, 
                      target_path: str, partition_keys: list = None) -> int:
    """Write curated data to the target location with optimization."""
    try:
        if not dynamic_frame:
            logger.warning("No data to write")
            return 0
            
        record_count = dynamic_frame.count()
        if record_count == 0:
            logger.warning("Dynamic frame is empty")
            return 0
            
        full_path = f"s3://{curated_bucket}/{target_path}"
        logger.info(f"Writing {record_count} records to {full_path}")
        
        # Default partition keys if none provided
        if partition_keys is None:
            partition_keys = ["year", "month", "day"]
        
        connection_options = {
            "path": full_path,
            "compression": "snappy"  # Better compression for Parquet
        }
        
        # Add partitioning if DataFrame has partition columns
        df = dynamic_frame.toDF()
        available_partition_keys = [key for key in partition_keys if key in df.columns]
        
        if available_partition_keys:
            connection_options["partitionKeys"] = available_partition_keys
            logger.info(f"Using partition keys: {available_partition_keys}")
        
        # Write to curated bucket in optimized Parquet format
        sink = glueContext.write_dynamic_frame.from_options(
            frame=dynamic_frame,
            connection_type="s3",
            connection_options=connection_options,
            format="parquet",
            format_options={
                "useThreads": True,
                "blockSize": 134217728,  # 128MB block size
                "pageSize": 1048576      # 1MB page size
            },
            transformation_ctx="curated_data_sink"
        )
        
        logger.info(f"Successfully wrote {record_count} records to {full_path}")
        return record_count
        
    except Exception as e:
        logger.error(f"Error writing curated data: {str(e)}")
        raise DataProcessingError(f"Failed to write curated data: {str(e)}")

def main():
    """Main ETL function with comprehensive error handling."""
    start_time = datetime.datetime.now()
    
    # Get job parameters
    try:
        args = get_job_metadata()
        job_name = args['JOB_NAME']
        processed_bucket = args['processed_bucket']
        curated_bucket = args['curated_bucket']
        environment = args['environment']
        state_table = args['state_table']
        database_name = args['database_name']
        sns_topic_arn = args.get('sns_topic_arn')
    except Exception as e:
        logger.error(f"Failed to get job metadata: {str(e)}")
        return
    
    # Initialize contexts
    try:
        sc, glueContext, spark, job = initialize_spark_context()
        job.init(job_name, args)
    except Exception as e:
        logger.error(f"Failed to initialize contexts: {str(e)}")
        return
    
    # Initialize AWS clients
    dynamodb = boto3.client('dynamodb')
    sns = boto3.client('sns')
    
    records_processed = 0
    
    try:
        # Update job state to RUNNING
        update_job_state(dynamodb, state_table, job_name, 'RUNNING', 
                        message="Job started successfully")
        
        # Calculate date partitions
        today = datetime.datetime.now()
        year = today.strftime("%Y")
        month = today.strftime("%m")
        day = today.strftime("%d")
        
        # Define source and target paths with better organization
        source_path = f"data/{year}/{month}/{day}/"
        target_path = f"curated/{year}/{month}/{day}/"
        
        logger.info(f"Processing data from {source_path} to {target_path}")
        
        # Get the latest processed data
        processed_data = get_latest_processed_data(glueContext, processed_bucket, source_path)
        
        if not processed_data:
            message = "No data found to process"
            logger.warning(message)
            update_job_state(dynamodb, state_table, job_name, 'SUCCEEDED', 
                           message=message, metadata={'records_processed': 0})
            if sns_topic_arn:
                send_notification(sns, sns_topic_arn, f"No Data - {job_name}", message)
            job.commit()
            return
        
        # Apply transformations
        curated_data = apply_transformations(glueContext, processed_data, environment)
        
        # Write curated data
        records_processed = write_curated_data(
            glueContext, 
            curated_data, 
            curated_bucket, 
            target_path,
            partition_keys=["year", "month", "day"]
        )
        
        # Calculate processing duration
        end_time = datetime.datetime.now()
        processing_duration = (end_time - start_time).total_seconds()
        
        # Prepare success metadata
        success_metadata = {
            'records_processed': records_processed,
            'source_path': source_path,
            'target_path': target_path,
            'processing_duration_seconds': processing_duration,
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat()
        }
        
        # Update job state to SUCCEEDED
        update_job_state(
            dynamodb, 
            state_table, 
            job_name, 
            'SUCCEEDED',
            message=f"Successfully processed {records_processed} records",
            metadata=success_metadata
        )
        
        # Send success notification
        if sns_topic_arn:
            success_message = f"""
Data Processing Job Completed Successfully

Job: {job_name}
Environment: {environment}
Records Processed: {records_processed:,}
Processing Duration: {processing_duration:.2f} seconds
Source: s3://{processed_bucket}/{source_path}
Target: s3://{curated_bucket}/{target_path}
"""
            send_notification(sns, sns_topic_arn, f"Success - {job_name}", success_message)
        
        logger.info(f"Job completed successfully. Processed {records_processed} records in {processing_duration:.2f} seconds")
        
        # Commit the job
        job.commit()
        
    except DataProcessingError as e:
        # Handle custom processing errors
        error_message = str(e)
        logger.error(f"Data processing error: {error_message}")
        
        update_job_state(dynamodb, state_table, job_name, 'FAILED', 
                        message=error_message,
                        metadata={'error_type': 'DataProcessingError', 'records_processed': records_processed})
        
        if sns_topic_arn:
            failure_message = f"""
Data Processing Job Failed

Job: {job_name}
Environment: {environment}
Error: {error_message}
Records Processed Before Failure: {records_processed}
"""
            send_notification(sns, sns_topic_arn, f"FAILED - {job_name}", failure_message)
        
        raise
        
    except Exception as e:
        # Handle unexpected errors
        error_message = f"Unexpected error: {str(e)}"
        logger.error(error_message)
        
        update_job_state(dynamodb, state_table, job_name, 'FAILED', 
                        message=error_message,
                        metadata={'error_type': 'UnexpectedError', 'records_processed': records_processed})
        
        if sns_topic_arn:
            failure_message = f"""
Data Processing Job Failed - Unexpected Error

Job: {job_name}
Environment: {environment}
Error: {error_message}
Records Processed Before Failure: {records_processed}
"""
            send_notification(sns, sns_topic_arn, f"CRITICAL FAILURE - {job_name}", failure_message)
        
        raise

if __name__ == "__main__":
    main()
