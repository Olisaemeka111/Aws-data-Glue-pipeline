import sys
import boto3
import time
from typing import Optional, Dict, Any, List
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType, DoubleType
import datetime
import uuid
import json
import logging
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

class DataIngestionError(Exception):
    """Custom exception for data ingestion errors."""
    pass

def get_job_metadata() -> Dict[str, str]:
    """Get job metadata from job parameters."""
    try:
        args = getResolvedOptions(sys.argv, [
            'JOB_NAME', 
            'raw_bucket', 
            'processed_bucket', 
            'environment',
            'state_table',
            'sns_topic_arn'
        ])
        return args
    except Exception as e:
        logger.error(f"Error parsing job arguments: {str(e)}")
        raise DataIngestionError(f"Failed to parse job arguments: {str(e)}")

def initialize_spark_context():
    """Initialize Spark and Glue contexts with optimized configuration."""
    try:
        sc = SparkContext()
        sc.setLogLevel("WARN")
        
        glueContext = GlueContext(sc)
        spark = glueContext.spark_session
        
        # Optimize Spark configuration for data ingestion
        spark.conf.set("spark.sql.adaptive.enabled", "true")
        spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
        spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
        spark.conf.set("spark.sql.parquet.enableVectorizedReader", "true")
        
        job = Job(glueContext)
        return sc, glueContext, spark, job
    except Exception as e:
        logger.error(f"Error initializing Spark context: {str(e)}")
        raise DataIngestionError(f"Failed to initialize Spark context: {str(e)}")

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
            item['message'] = {'S': str(message)[:1000]}
            
        if metadata:
            try:
                metadata_str = json.dumps(metadata, default=str)[:4000]
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

def send_notification(sns_client, topic_arn: str, subject: str, message: str) -> None:
    """Send SNS notification with error handling."""
    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject[:100],
            Message=message[:262144]
        )
        logger.info(f"Notification sent: {subject}")
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")

def detect_file_format(s3_client, bucket: str, key: str) -> str:
    """Detect file format based on file extension and content."""
    try:
        # Get file extension
        file_extension = key.lower().split('.')[-1] if '.' in key else ''
        
        # Map extensions to formats
        format_mapping = {
            'csv': 'csv',
            'tsv': 'csv',
            'txt': 'csv',
            'json': 'json',
            'jsonl': 'json',
            'parquet': 'parquet',
            'orc': 'orc',
            'avro': 'avro'
        }
        
        detected_format = format_mapping.get(file_extension, 'csv')  # Default to CSV
        logger.info(f"Detected format for {key}: {detected_format}")
        return detected_format
        
    except Exception as e:
        logger.warning(f"Error detecting file format for {key}: {str(e)}")
        return 'csv'  # Default fallback

def validate_data_quality(df, file_path: str) -> Dict[str, Any]:
    """Perform basic data quality validation."""
    quality_metrics = {}
    
    try:
        total_records = df.count()
        quality_metrics['total_records'] = total_records
        quality_metrics['total_columns'] = len(df.columns)
        
        if total_records == 0:
            quality_metrics['empty_file'] = True
            return quality_metrics
        
        quality_metrics['empty_file'] = False
        
        # Check for completely null columns
        null_columns = []
        for column in df.columns:
            null_count = df.filter(F.col(column).isNull()).count()
            null_percentage = (null_count / total_records) * 100
            
            if null_percentage == 100:
                null_columns.append(column)
            
            quality_metrics[f'{column}_null_percentage'] = round(null_percentage, 2)
        
        quality_metrics['completely_null_columns'] = null_columns
        
        # Check for duplicate records
        distinct_records = df.distinct().count()
        duplicate_percentage = ((total_records - distinct_records) / total_records) * 100
        quality_metrics['duplicate_percentage'] = round(duplicate_percentage, 2)
        
        # Schema information
        quality_metrics['schema'] = [{'column': field.name, 'type': str(field.dataType)} 
                                   for field in df.schema.fields]
        
        logger.info(f"Data quality metrics for {file_path}: {quality_metrics}")
        return quality_metrics
        
    except Exception as e:
        logger.error(f"Error validating data quality: {str(e)}")
        return {'error': str(e)}

def get_source_files(s3_client, raw_bucket: str, source_path: str) -> List[str]:
    """Get list of source files to process."""
    try:
        files = []
        paginator = s3_client.get_paginator('list_objects_v2')
        
        for page in paginator.paginate(Bucket=raw_bucket, Prefix=source_path):
            if 'Contents' in page:
                for obj in page['Contents']:
                    key = obj['Key']
                    # Skip directories and hidden files
                    if not key.endswith('/') and not key.split('/')[-1].startswith('.'):
                        files.append(key)
        
        logger.info(f"Found {len(files)} files to process in s3://{raw_bucket}/{source_path}")
        return files
        
    except Exception as e:
        logger.error(f"Error listing source files: {str(e)}")
        raise DataIngestionError(f"Failed to list source files: {str(e)}")

def process_source_data(glueContext, spark, raw_bucket: str, source_path: str, 
                       processed_bucket: str, target_path: str, environment: str) -> Dict[str, Any]:
    """Process source data and write to processed bucket with comprehensive handling."""
    try:
        s3_client = boto3.client('s3')
        processing_summary = {
            'files_processed': 0,
            'total_records': 0,
            'errors': [],
            'quality_metrics': {}
        }
        
        # Get list of source files
        source_files = get_source_files(s3_client, raw_bucket, source_path)
        
        if not source_files:
            logger.warning(f"No files found in s3://{raw_bucket}/{source_path}")
            return processing_summary
        
        all_dataframes = []
        
        for file_key in source_files:
            try:
                logger.info(f"Processing file: {file_key}")
                
                # Detect file format
                file_format = detect_file_format(s3_client, raw_bucket, file_key)
                
                # Read file based on format
                connection_options = {
                    "paths": [f"s3://{raw_bucket}/{file_key}"]
                }
                
                format_options = {}
                if file_format == 'csv':
                    format_options = {
                        "withHeader": True,
                        "separator": ",",
                        "optimizePerformance": True,
                        "multiline": False
                    }
                elif file_format == 'json':
                    format_options = {
                        "multiline": True
                    }
                
                dynamic_frame = glueContext.create_dynamic_frame.from_options(
                    connection_type="s3",
                    connection_options=connection_options,
                    format=file_format,
                    format_options=format_options
                )
                
                if dynamic_frame.count() == 0:
                    logger.warning(f"No data in file: {file_key}")
                    continue
                
                # Convert to DataFrame for processing
                df = dynamic_frame.toDF()
                
                # Validate data quality
                quality_metrics = validate_data_quality(df, file_key)
                processing_summary['quality_metrics'][file_key] = quality_metrics
                
                # Add file metadata
                df = df.withColumn("source_file", F.lit(file_key))
                df = df.withColumn("ingestion_timestamp", F.current_timestamp())
                df = df.withColumn("batch_id", F.lit(str(uuid.uuid4())))
                df = df.withColumn("file_format", F.lit(file_format))
                df = df.withColumn("environment", F.lit(environment))
                
                # Add date partitions
                current_date = datetime.datetime.now()
                df = df.withColumn("year", F.lit(current_date.year))
                df = df.withColumn("month", F.lit(current_date.month))
                df = df.withColumn("day", F.lit(current_date.day))
                
                # Data cleaning and standardization
                # Clean column names (remove special characters, spaces)
                for old_col in df.columns:
                    new_col = old_col.strip().replace(' ', '_').replace('-', '_').replace('.', '_')
                    new_col = ''.join(c for c in new_col if c.isalnum() or c == '_')
                    if new_col != old_col and new_col not in df.columns:
                        df = df.withColumnRenamed(old_col, new_col)
                
                all_dataframes.append(df)
                processing_summary['files_processed'] += 1
                processing_summary['total_records'] += df.count()
                
                logger.info(f"Successfully processed file: {file_key} with {df.count()} records")
                
            except Exception as e:
                error_msg = f"Error processing file {file_key}: {str(e)}"
                logger.error(error_msg)
                processing_summary['errors'].append(error_msg)
                continue
        
        if not all_dataframes:
            logger.warning("No valid data found to process")
            return processing_summary
        
        # Union all DataFrames
        logger.info(f"Combining {len(all_dataframes)} DataFrames")
        combined_df = all_dataframes[0]
        
        for df in all_dataframes[1:]:
            # Ensure schema compatibility before union
            try:
                combined_df = combined_df.unionByName(df, allowMissingColumns=True)
            except Exception as e:
                logger.warning(f"Schema mismatch, using union: {str(e)}")
                combined_df = combined_df.union(df)
        
        # Convert back to DynamicFrame
        dynamic_frame_output = DynamicFrame.fromDF(combined_df, glueContext, "ingested_data")
        
        # Write to processed bucket in Parquet format with partitioning
        full_target_path = f"s3://{processed_bucket}/{target_path}"
        logger.info(f"Writing {processing_summary['total_records']} records to {full_target_path}")
        
        sink = glueContext.write_dynamic_frame.from_options(
            frame=dynamic_frame_output,
            connection_type="s3",
            connection_options={
                "path": full_target_path,
                "partitionKeys": ["year", "month", "day"],
                "compression": "snappy"
            },
            format="parquet",
            format_options={
                "useThreads": True,
                "blockSize": 134217728,  # 128MB
                "pageSize": 1048576      # 1MB
            },
            transformation_ctx="processed_data_sink"
        )
        
        logger.info(f"Successfully wrote data to {full_target_path}")
        return processing_summary
        
    except DataIngestionError:
        raise
    except Exception as e:
        logger.error(f"Error in process_source_data: {str(e)}")
        raise DataIngestionError(f"Failed to process source data: {str(e)}")

def main():
    """Main ETL function with comprehensive error handling."""
    start_time = datetime.datetime.now()
    
    # Get job parameters
    try:
        args = get_job_metadata()
        job_name = args['JOB_NAME']
        raw_bucket = args['raw_bucket']
        processed_bucket = args['processed_bucket']
        environment = args['environment']
        state_table = args['state_table']
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
    
    processing_summary = {'files_processed': 0, 'total_records': 0}
    
    try:
        # Update job state to RUNNING
        update_job_state(dynamodb, state_table, job_name, 'RUNNING',
                        message="Data ingestion job started")
        
        # Calculate date partitions
        today = datetime.datetime.now()
        year = today.strftime("%Y")
        month = today.strftime("%m")
        day = today.strftime("%d")
        
        # Define source and target paths
        source_path = f"data/incoming/{year}/{month}/{day}/"
        target_path = f"data/{year}/{month}/{day}/"
        
        logger.info(f"Ingesting data from {source_path} to {target_path}")
        
        # Process the data
        processing_summary = process_source_data(
            glueContext, 
            spark, 
            raw_bucket, 
            source_path, 
            processed_bucket, 
            target_path,
            environment
        )
        
        # Calculate processing duration
        end_time = datetime.datetime.now()
        processing_duration = (end_time - start_time).total_seconds()
        
        # Prepare metadata
        metadata = {
            'files_processed': processing_summary['files_processed'],
            'records_processed': processing_summary['total_records'],
            'source_path': source_path,
            'target_path': target_path,
            'processing_duration_seconds': processing_duration,
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat(),
            'errors_count': len(processing_summary.get('errors', []))
        }
        
        # Determine job status
        if processing_summary['files_processed'] == 0:
            status = 'SUCCEEDED'
            message = "No files found to process"
        elif processing_summary.get('errors'):
            status = 'SUCCEEDED_WITH_WARNINGS'
            message = f"Processed {processing_summary['files_processed']} files with {len(processing_summary['errors'])} errors"
        else:
            status = 'SUCCEEDED'
            message = f"Successfully processed {processing_summary['files_processed']} files"
        
        # Update job state
        update_job_state(
            dynamodb, 
            state_table, 
            job_name, 
            status,
            message=message,
            metadata=metadata
        )
        
        # Send notification
        if sns_topic_arn:
            notification_message = f"""
Data Ingestion Job Completed

Job: {job_name}
Environment: {environment}
Status: {status}
Files Processed: {processing_summary['files_processed']}
Records Processed: {processing_summary['total_records']:,}
Duration: {processing_duration:.2f} seconds
Source: s3://{raw_bucket}/{source_path}
Target: s3://{processed_bucket}/{target_path}

{f"Errors: {len(processing_summary.get('errors', []))}" if processing_summary.get('errors') else "No errors"}
"""
            send_notification(sns, sns_topic_arn, f"{status} - {job_name}", notification_message)
        
        logger.info(f"Job completed with status: {status}")
        
        # Commit the job
        job.commit()
        
    except DataIngestionError as e:
        # Handle custom ingestion errors
        error_message = str(e)
        logger.error(f"Data ingestion error: {error_message}")
        
        update_job_state(dynamodb, state_table, job_name, 'FAILED', 
                        message=error_message,
                        metadata={'error_type': 'DataIngestionError', 
                                'files_processed': processing_summary['files_processed']})
        
        if sns_topic_arn:
            failure_message = f"""
Data Ingestion Job Failed

Job: {job_name}
Environment: {environment}
Error: {error_message}
Files Processed Before Failure: {processing_summary['files_processed']}
"""
            send_notification(sns, sns_topic_arn, f"FAILED - {job_name}", failure_message)
        
        raise
        
    except Exception as e:
        # Handle unexpected errors
        error_message = f"Unexpected error: {str(e)}"
        logger.error(error_message)
        
        update_job_state(dynamodb, state_table, job_name, 'FAILED', 
                        message=error_message,
                        metadata={'error_type': 'UnexpectedError',
                                'files_processed': processing_summary['files_processed']})
        
        if sns_topic_arn:
            failure_message = f"""
Data Ingestion Job Failed - Unexpected Error

Job: {job_name}
Environment: {environment}
Error: {error_message}
Files Processed Before Failure: {processing_summary['files_processed']}
"""
            send_notification(sns, sns_topic_arn, f"CRITICAL FAILURE - {job_name}", failure_message)
        
        raise

if __name__ == "__main__":
    main()
