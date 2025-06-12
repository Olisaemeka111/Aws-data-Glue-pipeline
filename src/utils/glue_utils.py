import boto3
import datetime
import json
import logging
import os
import uuid
from typing import Optional, Dict, Any, List, Union, Callable
from functools import wraps
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import DataFrame, functions as F
from pyspark.sql.types import *

# Configure logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

class GlueJobError(Exception):
    """Custom exception for Glue job errors."""
    pass

class DataQualityError(Exception):
    """Custom exception for data quality errors."""
    pass

def retry_on_failure(max_retries: int = 3, delay: int = 5):
    """Decorator to retry function calls on failure."""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        logger.warning(f"Attempt {attempt + 1} failed for {func.__name__}: {str(e)}. Retrying in {delay} seconds...")
                        import time
                        time.sleep(delay)
                    else:
                        logger.error(f"All {max_retries} attempts failed for {func.__name__}")
            raise last_exception
        return wrapper
    return decorator

class GlueJobUtils:
    """Enhanced utility class for AWS Glue ETL jobs."""
    
    def __init__(self, glue_context: GlueContext, job_name: str, state_table: str, 
                 environment: str = "dev"):
        """Initialize the utility class with enhanced configuration.
        
        Args:
            glue_context: GlueContext instance
            job_name: Name of the Glue job
            state_table: DynamoDB table name for job state
            environment: Environment (dev, staging, prod)
        """
        self.glue_context = glue_context
        self.job_name = job_name
        self.state_table = state_table
        self.environment = environment
        
        # Initialize AWS clients with error handling
        try:
            self.dynamodb = boto3.client('dynamodb')
            self.s3 = boto3.client('s3')
            self.sns = boto3.client('sns')
            self.cloudwatch = boto3.client('cloudwatch')
        except Exception as e:
            logger.error(f"Error initializing AWS clients: {str(e)}")
            raise GlueJobError(f"Failed to initialize AWS clients: {str(e)}")
    
    @retry_on_failure(max_retries=3)
    def update_job_state(self, status: str, message: Optional[str] = None, 
                        metadata: Optional[Dict[str, Any]] = None) -> None:
        """Update job state in DynamoDB with retry logic.
        
        Args:
            status: Job status (e.g., RUNNING, SUCCEEDED, FAILED)
            message: Optional status message
            metadata: Optional metadata dictionary
        """
        try:
            item = {
                'job_name': {'S': self.job_name},
                'status': {'S': status},
                'updated_at': {'S': datetime.datetime.now().isoformat()},
                'environment': {'S': self.environment},
                'ttl': {'N': str(int((datetime.datetime.now() + datetime.timedelta(days=30)).timestamp()))}
            }
            
            if message:
                # Truncate message to fit DynamoDB limits
                item['message'] = {'S': str(message)[:1000]}
                
            if metadata:
                try:
                    # Ensure metadata is JSON serializable and within size limits
                    metadata_str = json.dumps(metadata, default=str, separators=(',', ':'))[:4000]
                    item['metadata'] = {'S': metadata_str}
                except (TypeError, ValueError) as e:
                    logger.warning(f"Error serializing metadata: {str(e)}")
                    item['metadata'] = {'S': '{"error": "metadata_serialization_failed"}'}
                
            self.dynamodb.put_item(
                TableName=self.state_table,
                Item=item
            )
            logger.info(f"Updated job state: {status}")
            
            # Send custom CloudWatch metric
            self._send_custom_metric("JobStateUpdate", 1, {"Status": status})
            
        except Exception as e:
            logger.error(f"Error updating job state: {str(e)}")
            raise
    
    def _send_custom_metric(self, metric_name: str, value: float, 
                          dimensions: Optional[Dict[str, str]] = None) -> None:
        """Send custom metric to CloudWatch."""
        try:
            metric_data = {
                'MetricName': metric_name,
                'Value': value,
                'Unit': 'Count',
                'Timestamp': datetime.datetime.utcnow()
            }
            
            if dimensions:
                metric_data['Dimensions'] = [
                    {'Name': k, 'Value': v} for k, v in dimensions.items()
                ]
            
            self.cloudwatch.put_metric_data(
                Namespace=f'Glue/ETL/{self.environment}',
                MetricData=[metric_data]
            )
        except Exception as e:
            logger.warning(f"Error sending CloudWatch metric: {str(e)}")
    
    @retry_on_failure(max_retries=2)
    def send_notification(self, topic_arn: str, subject: str, message: str, 
                         message_attributes: Optional[Dict[str, Any]] = None) -> None:
        """Send enhanced SNS notification with attributes.
        
        Args:
            topic_arn: SNS topic ARN
            subject: Notification subject
            message: Notification message
            message_attributes: Optional message attributes for filtering
        """
        try:
            publish_kwargs = {
                'TopicArn': topic_arn,
                'Subject': subject[:100],  # SNS subject limit
                'Message': message[:262144]  # SNS message limit
            }
            
            # Add message attributes if provided
            if message_attributes:
                sns_attributes = {}
                for key, value in message_attributes.items():
                    if isinstance(value, str):
                        sns_attributes[key] = {'DataType': 'String', 'StringValue': value}
                    elif isinstance(value, (int, float)):
                        sns_attributes[key] = {'DataType': 'Number', 'StringValue': str(value)}
                publish_kwargs['MessageAttributes'] = sns_attributes
            
            self.sns.publish(**publish_kwargs)
            logger.info(f"Notification sent: {subject}")
            
        except Exception as e:
            logger.error(f"Error sending notification: {str(e)}")
            raise
    
    def check_s3_path_exists(self, bucket: str, path: str) -> bool:
        """Check if S3 path exists and has objects."""
        try:
            response = self.s3.list_objects_v2(
                Bucket=bucket,
                Prefix=path,
                MaxKeys=1
            )
            return response.get('KeyCount', 0) > 0
        except Exception as e:
            logger.error(f"Error checking S3 path existence: {str(e)}")
            return False
    
    def get_s3_object_count(self, bucket: str, path: str) -> int:
        """Get count of objects in S3 path."""
        try:
            count = 0
            paginator = self.s3.get_paginator('list_objects_v2')
            
            for page in paginator.paginate(Bucket=bucket, Prefix=path):
                if 'Contents' in page:
                    count += len([obj for obj in page['Contents'] 
                                if not obj['Key'].endswith('/')])
            
            return count
        except Exception as e:
            logger.error(f"Error counting S3 objects: {str(e)}")
            return 0
    
    def read_from_s3(self, bucket: str, path: str, format: str = "parquet", 
                    options: Optional[Dict[str, Any]] = None, 
                    schema: Optional[StructType] = None) -> Optional[DynamicFrame]:
        """Read data from S3 with enhanced error handling and optimization.
        
        Args:
            bucket: S3 bucket name
            path: S3 path
            format: File format (default: parquet)
            options: Additional format options
            schema: Optional schema for schema enforcement
            
        Returns:
            DynamicFrame containing the data or None if no data found
        """
        try:
            full_path = f"s3://{bucket}/{path}"
            logger.info(f"Reading data from {full_path}")
            
            # Check if path exists
            if not self.check_s3_path_exists(bucket, path):
                logger.warning(f"No data found in {full_path}")
                return None
            
            connection_options = {
                "paths": [full_path],
                "recurse": True,
                "optimizePerformance": True
            }
            
            # Merge with provided options
            if options:
                connection_options.update(options)
            
            format_options = {"useThreads": True}
            
            # Format-specific optimizations
            if format == "csv":
                format_options.update({
                    "withHeader": True,
                    "separator": ",",
                    "multiline": False,
                    "ignoreLeadingWhiteSpace": True,
                    "ignoreTrailingWhiteSpace": True
                })
            elif format == "parquet":
                format_options.update({
                    "optimizePerformance": True,
                    "enableVectorizedReader": True
                })
            elif format == "json":
                format_options.update({
                    "multiline": True
                })
            
            # Apply schema if provided
            if schema:
                format_options["enforceSchema"] = "true"
            
            dynamic_frame = self.glue_context.create_dynamic_frame.from_options(
                connection_type="s3",
                connection_options=connection_options,
                format=format,
                format_options=format_options
            )
            
            record_count = dynamic_frame.count()
            if record_count == 0:
                logger.warning(f"No records found in {full_path}")
                return None
            
            logger.info(f"Successfully read {record_count:,} records from {full_path}")
            
            # Send metrics
            self._send_custom_metric("RecordsRead", record_count, {"Source": bucket})
            
            return dynamic_frame
            
        except Exception as e:
            logger.error(f"Error reading from S3: {str(e)}")
            self._send_custom_metric("ReadErrors", 1, {"Source": bucket, "Error": "S3ReadError"})
            raise GlueJobError(f"Failed to read from S3: {str(e)}")
    
    def write_to_s3(self, dynamic_frame: DynamicFrame, bucket: str, path: str, 
                   format: str = "parquet", partition_keys: Optional[List[str]] = None,
                   write_mode: str = "append", compression: str = "snappy") -> int:
        """Write data to S3 with enhanced configuration and monitoring.
        
        Args:
            dynamic_frame: DynamicFrame to write
            bucket: S3 bucket name
            path: S3 path
            format: File format (default: parquet)
            partition_keys: List of partition keys
            write_mode: Write mode (append, overwrite)
            compression: Compression codec
            
        Returns:
            Number of records written
        """
        try:
            if not dynamic_frame or dynamic_frame.count() == 0:
                logger.warning("No data to write")
                return 0
                
            record_count = dynamic_frame.count()
            full_path = f"s3://{bucket}/{path}"
            logger.info(f"Writing {record_count:,} records to {full_path}")
            
            connection_options = {
                "path": full_path,
                "compression": compression
            }
            
            # Add partitioning if specified and columns exist
            if partition_keys:
                df = dynamic_frame.toDF()
                available_partition_keys = [key for key in partition_keys if key in df.columns]
                
                if available_partition_keys:
                    connection_options["partitionKeys"] = available_partition_keys
                    logger.info(f"Using partition keys: {available_partition_keys}")
                else:
                    logger.warning(f"None of the specified partition keys {partition_keys} found in data")
            
            # Set write mode
            if write_mode == "overwrite":
                connection_options["enableUpdateCatalog"] = True
                connection_options["updateBehavior"] = "UPDATE_IN_DATABASE"
            
            format_options = {"useThreads": True}
            
            # Format-specific optimizations
            if format == "parquet":
                format_options.update({
                    "blockSize": 134217728,  # 128MB
                    "pageSize": 1048576,     # 1MB
                    "enableDictionary": True
                })
            elif format == "orc":
                format_options.update({
                    "blockSize": 134217728,
                    "stripe": 67108864  # 64MB
                })
            
            # Perform the write operation
            sink = self.glue_context.write_dynamic_frame.from_options(
                frame=dynamic_frame,
                connection_type="s3",
                connection_options=connection_options,
                format=format,
                format_options=format_options,
                transformation_ctx=f"write_to_{bucket.replace('-', '_')}"
            )
            
            logger.info(f"Successfully wrote {record_count:,} records to {full_path}")
            
            # Send metrics
            self._send_custom_metric("RecordsWritten", record_count, {"Destination": bucket})
            
            return record_count
            
        except Exception as e:
            logger.error(f"Error writing to S3: {str(e)}")
            self._send_custom_metric("WriteErrors", 1, {"Destination": bucket, "Error": "S3WriteError"})
            raise GlueJobError(f"Failed to write to S3: {str(e)}")
    
    def add_audit_columns(self, dynamic_frame: DynamicFrame, 
                         batch_id: Optional[str] = None,
                         additional_metadata: Optional[Dict[str, Any]] = None) -> DynamicFrame:
        """Add comprehensive audit columns to the data.
        
        Args:
            dynamic_frame: Input DynamicFrame
            batch_id: Optional batch ID (UUID will be generated if not provided)
            additional_metadata: Additional metadata to include
            
        Returns:
            DynamicFrame with audit columns added
        """
        try:
            if not dynamic_frame:
                return dynamic_frame
                
            # Convert to DataFrame for transformations
            df = dynamic_frame.toDF()
            
            # Add standard audit columns
            df = df.withColumn("processing_timestamp", F.current_timestamp())
            df = df.withColumn("processing_date", F.current_date())
            
            # Add batch ID
            if batch_id:
                df = df.withColumn("batch_id", F.lit(batch_id))
            else:
                df = df.withColumn("batch_id", F.lit(str(uuid.uuid4())))
                
            # Add job and environment information
            df = df.withColumn("job_name", F.lit(self.job_name))
            df = df.withColumn("environment", F.lit(self.environment))
            df = df.withColumn("data_version", F.lit("1.0"))
            
            # Add data lineage information
            df = df.withColumn("source_system", F.lit("glue_etl_pipeline"))
            df = df.withColumn("last_modified_by", F.lit(self.job_name))
            
            # Add record hash for change detection
            df = df.withColumn("record_hash", 
                             F.sha2(F.concat_ws("|", *[F.col(c) for c in df.columns]), 256))
            
            # Add additional metadata if provided
            if additional_metadata:
                for key, value in additional_metadata.items():
                    df = df.withColumn(f"metadata_{key}", F.lit(str(value)))
            
            # Convert back to DynamicFrame
            return DynamicFrame.fromDF(df, self.glue_context, "dynamic_frame_with_audit")
            
        except Exception as e:
            logger.error(f"Error adding audit columns: {str(e)}")
            raise GlueJobError(f"Failed to add audit columns: {str(e)}")
    
    def get_date_partitions(self, date: Optional[datetime.datetime] = None) -> Dict[str, str]:
        """Get date partition values with enhanced formatting.
        
        Args:
            date: Date to use (default: current date)
            
        Returns:
            Dictionary with partition keys and values
        """
        if date is None:
            date = datetime.datetime.now()
            
        return {
            "year": date.strftime("%Y"),
            "month": date.strftime("%m"),
            "day": date.strftime("%d"),
            "hour": date.strftime("%H"),
            "quarter": f"Q{((date.month - 1) // 3) + 1}",
            "week": date.strftime("%U"),
            "day_of_week": date.strftime("%w"),
            "day_of_year": date.strftime("%j")
        }
    
    def handle_errors(self, func: Callable, *args, **kwargs) -> Any:
        """Enhanced error handling wrapper with detailed logging.
        
        Args:
            func: Function to execute
            *args: Function arguments
            **kwargs: Function keyword arguments
            
        Returns:
            Function result or raises exception
        """
        try:
            start_time = datetime.datetime.now()
            result = func(*args, **kwargs)
            duration = (datetime.datetime.now() - start_time).total_seconds()
            
            logger.info(f"Successfully executed {func.__name__} in {duration:.2f} seconds")
            self._send_custom_metric("FunctionExecutionTime", duration, {"Function": func.__name__})
            
            return result
            
        except Exception as e:
            error_details = {
                "function": func.__name__,
                "error": str(e),
                "error_type": type(e).__name__,
                "job_name": self.job_name,
                "environment": self.environment
            }
            
            logger.error(f"Error in {func.__name__}: {error_details}")
            self._send_custom_metric("FunctionErrors", 1, 
                                   {"Function": func.__name__, "ErrorType": type(e).__name__})
            
            # Update job state with error
            self.update_job_state("FAILED", f"Error in {func.__name__}: {str(e)}", error_details)
            
            raise
    
    def optimize_dataframe(self, df: DataFrame, target_partitions: Optional[int] = None) -> DataFrame:
        """Optimize DataFrame partitioning and caching.
        
        Args:
            df: Input DataFrame
            target_partitions: Target number of partitions
            
        Returns:
            Optimized DataFrame
        """
        try:
            # Calculate optimal partitions if not specified
            if target_partitions is None:
                row_count = df.count()
                # Aim for ~100MB per partition (assuming 1KB per row)
                target_partitions = max(1, min(200, row_count // 100000))
            
            # Repartition if needed
            current_partitions = df.rdd.getNumPartitions()
            if current_partitions != target_partitions:
                logger.info(f"Repartitioning from {current_partitions} to {target_partitions} partitions")
                df = df.repartition(target_partitions)
            
            # Cache if data will be accessed multiple times
            df.cache()
            
            return df
            
        except Exception as e:
            logger.warning(f"Error optimizing DataFrame: {str(e)}")
            return df  # Return original DataFrame if optimization fails


class DataQualityChecker:
    """Enhanced data quality checker with comprehensive validation rules."""
    
    def __init__(self, glue_context: GlueContext, job_utils: GlueJobUtils):
        """Initialize the data quality checker.
        
        Args:
            glue_context: GlueContext instance
            job_utils: GlueJobUtils instance for logging and metrics
        """
        self.glue_context = glue_context
        self.job_utils = job_utils
        self.spark = glue_context.spark_session
    
    def run_quality_checks(self, dynamic_frame: DynamicFrame, 
                          quality_rules: List[Dict[str, Any]],
                          fail_on_error: bool = False) -> Dict[str, Any]:
        """Run comprehensive data quality checks with detailed reporting.
        
        Args:
            dynamic_frame: DynamicFrame to validate
            quality_rules: List of quality rules to apply
            fail_on_error: Whether to raise exception on quality failures
            
        Returns:
            Dictionary with quality check results
        """
        if not dynamic_frame:
            return {"error": "No data provided for quality checks"}
        
        try:
            df = dynamic_frame.toDF()
            total_records = df.count()
            
            # Initialize results
            quality_results = {
                "total_records": total_records,
                "total_rules": len(quality_rules),
                "passed_rules": 0,
                "failed_rules": 0,
                "overall_score": 0.0,
                "rule_results": [],
                "summary": {}
            }
            
            if total_records == 0:
                quality_results["error"] = "Dataset is empty"
                return quality_results
            
            # Register DataFrame as temp view for SQL-based checks
            df.createOrReplaceTempView("data_quality_table")
            
            # Process each quality rule
            for rule in quality_rules:
                rule_result = self._execute_quality_rule(df, rule, total_records)
                quality_results["rule_results"].append(rule_result)
                
                if rule_result["passed"]:
                    quality_results["passed_rules"] += 1
                else:
                    quality_results["failed_rules"] += 1
            
            # Calculate overall quality score
            quality_results["overall_score"] = (
                quality_results["passed_rules"] / quality_results["total_rules"] * 100
                if quality_results["total_rules"] > 0 else 0
            )
            
            # Generate summary
            quality_results["summary"] = self._generate_quality_summary(quality_results)
            
            # Send quality metrics
            self.job_utils._send_custom_metric("DataQualityScore", 
                                             quality_results["overall_score"],
                                             {"JobName": self.job_utils.job_name})
            
            # Log results
            logger.info(f"Data quality check completed. Score: {quality_results['overall_score']:.1f}%")
            
            # Raise exception if configured and quality checks failed
            if fail_on_error and quality_results["failed_rules"] > 0:
                raise DataQualityError(f"Data quality checks failed. Score: {quality_results['overall_score']:.1f}%")
            
            return quality_results
            
        except Exception as e:
            error_msg = f"Error running quality checks: {str(e)}"
            logger.error(error_msg)
            if fail_on_error:
                raise DataQualityError(error_msg)
            return {"error": error_msg}
    
    def _execute_quality_rule(self, df: DataFrame, rule: Dict[str, Any], 
                             total_records: int) -> Dict[str, Any]:
        """Execute a single quality rule."""
        rule_id = rule.get('id', f"rule_{uuid.uuid4().hex[:8]}")
        rule_name = rule.get('name', 'Unnamed Rule')
        rule_type = rule.get('type')
        threshold = rule.get('threshold', 95.0)  # Default 95% pass rate
        
        result = {
            'rule_id': rule_id,
            'rule_name': rule_name,
            'rule_type': rule_type,
            'threshold': threshold,
            'passed': False,
            'score': 0.0,
            'metrics': {},
            'details': {}
        }
        
        try:
            if rule_type == 'null_check':
                result = self._apply_null_check(df, rule, result, total_records)
            elif rule_type == 'uniqueness_check':
                result = self._apply_uniqueness_check(df, rule, result, total_records)
            elif rule_type == 'range_check':
                result = self._apply_range_check(df, rule, result, total_records)
            elif rule_type == 'pattern_check':
                result = self._apply_pattern_check(df, rule, result, total_records)
            elif rule_type == 'custom_sql':
                result = self._apply_custom_sql_check(rule, result)
            elif rule_type == 'completeness_check':
                result = self._apply_completeness_check(df, rule, result, total_records)
            elif rule_type == 'consistency_check':
                result = self._apply_consistency_check(df, rule, result, total_records)
            else:
                result['error'] = f"Unknown rule type: {rule_type}"
                
        except Exception as e:
            result['error'] = str(e)
            logger.error(f"Error executing rule {rule_id}: {str(e)}")
        
        return result
    
    def _apply_null_check(self, df: DataFrame, rule: Dict[str, Any], 
                         result: Dict[str, Any], total_records: int) -> Dict[str, Any]:
        """Apply null value checks."""
        columns = rule.get('columns', [])
        threshold = rule.get('threshold', 95.0)
        
        if not columns:
            result['error'] = "No columns specified for null check"
            return result
        
        column_results = {}
        total_score = 0
        
        for column in columns:
            if column not in df.columns:
                column_results[column] = {'error': f"Column {column} not found"}
                continue
                
            null_count = df.filter(F.col(column).isNull()).count()
            valid_count = total_records - null_count
            completeness_rate = (valid_count / total_records * 100) if total_records > 0 else 0
            
            column_passed = completeness_rate >= threshold
            
            column_results[column] = {
                'null_count': null_count,
                'valid_count': valid_count,
                'completeness_rate': round(completeness_rate, 2),
                'passed': column_passed,
                'threshold': threshold
            }
            
            total_score += completeness_rate
        
        # Calculate overall score for this rule
        avg_score = total_score / len([c for c in columns if c in df.columns])
        result['score'] = round(avg_score, 2)
        result['passed'] = avg_score >= threshold
        result['metrics'] = column_results
        
        return result
    
    def _apply_uniqueness_check(self, df: DataFrame, rule: Dict[str, Any], 
                               result: Dict[str, Any], total_records: int) -> Dict[str, Any]:
        """Apply uniqueness checks."""
        columns = rule.get('columns', [])
        threshold = rule.get('threshold', 100.0)
        
        if not columns:
            result['error'] = "No columns specified for uniqueness check"
            return result
        
        # Check uniqueness for each column or combination
        if len(columns) == 1:
            column = columns[0]
            if column not in df.columns:
                result['error'] = f"Column {column} not found"
                return result
                
            distinct_count = df.select(column).distinct().count()
            uniqueness_rate = (distinct_count / total_records * 100) if total_records > 0 else 0
            
            result['metrics'] = {
                'distinct_count': distinct_count,
                'total_count': total_records,
                'uniqueness_rate': round(uniqueness_rate, 2),
                'duplicate_count': total_records - distinct_count
            }
        else:
            # Check uniqueness of column combination
            distinct_count = df.select(*columns).distinct().count()
            uniqueness_rate = (distinct_count / total_records * 100) if total_records > 0 else 0
            
            result['metrics'] = {
                'distinct_combinations': distinct_count,
                'total_count': total_records,
                'uniqueness_rate': round(uniqueness_rate, 2),
                'duplicate_combinations': total_records - distinct_count
            }
        
        result['score'] = result['metrics']['uniqueness_rate']
        result['passed'] = result['score'] >= threshold
        
        return result
    
    def _apply_range_check(self, df: DataFrame, rule: Dict[str, Any], 
                          result: Dict[str, Any], total_records: int) -> Dict[str, Any]:
        """Apply range validation checks."""
        column = rule.get('column')
        min_value = rule.get('min_value')
        max_value = rule.get('max_value')
        threshold = rule.get('threshold', 95.0)
        
        if not column or column not in df.columns:
            result['error'] = f"Column {column} not found"
            return result
        
        if min_value is None and max_value is None:
            result['error'] = "Neither min_value nor max_value specified"
            return result
        
        # Build range condition
        conditions = []
        if min_value is not None:
            conditions.append(F.col(column) >= min_value)
        if max_value is not None:
            conditions.append(F.col(column) <= max_value)
        
        range_condition = conditions[0]
        for condition in conditions[1:]:
            range_condition = range_condition & condition
        
        valid_count = df.filter(range_condition).count()
        invalid_count = total_records - valid_count
        validity_rate = (valid_count / total_records * 100) if total_records > 0 else 0
        
        result['metrics'] = {
            'valid_count': valid_count,
            'invalid_count': invalid_count,
            'validity_rate': round(validity_rate, 2),
            'min_value': min_value,
            'max_value': max_value
        }
        
        result['score'] = validity_rate
        result['passed'] = validity_rate >= threshold
        
        return result
    
    def _apply_pattern_check(self, df: DataFrame, rule: Dict[str, Any], 
                            result: Dict[str, Any], total_records: int) -> Dict[str, Any]:
        """Apply pattern matching checks using regex."""
        column = rule.get('column')
        pattern = rule.get('pattern')
        threshold = rule.get('threshold', 95.0)
        
        if not column or column not in df.columns:
            result['error'] = f"Column {column} not found"
            return result
        
        if not pattern:
            result['error'] = "No pattern specified"
            return result
        
        # Apply regex pattern
        valid_count = df.filter(F.col(column).rlike(pattern)).count()
        invalid_count = total_records - valid_count
        match_rate = (valid_count / total_records * 100) if total_records > 0 else 0
        
        result['metrics'] = {
            'matching_count': valid_count,
            'non_matching_count': invalid_count,
            'match_rate': round(match_rate, 2),
            'pattern': pattern
        }
        
        result['score'] = match_rate
        result['passed'] = match_rate >= threshold
        
        return result
    
    def _apply_custom_sql_check(self, rule: Dict[str, Any], result: Dict[str, Any]) -> Dict[str, Any]:
        """Apply custom SQL-based checks."""
        sql_query = rule.get('sql_query')
        threshold = rule.get('threshold', 0)
        
        if not sql_query:
            result['error'] = "No SQL query specified"
            return result
        
        try:
            query_result = self.spark.sql(sql_query)
            result_value = query_result.collect()[0][0] if query_result.count() > 0 else 0
            
            result['metrics'] = {
                'query_result': result_value,
                'threshold': threshold,
                'sql_query': sql_query
            }
            
            result['score'] = result_value
            result['passed'] = result_value >= threshold
            
        except Exception as e:
            result['error'] = f"SQL execution error: {str(e)}"
        
        return result
    
    def _apply_completeness_check(self, df: DataFrame, rule: Dict[str, Any], 
                                 result: Dict[str, Any], total_records: int) -> Dict[str, Any]:
        """Apply completeness checks (non-null and non-empty)."""
        columns = rule.get('columns', [])
        threshold = rule.get('threshold', 95.0)
        
        if not columns:
            result['error'] = "No columns specified for completeness check"
            return result
        
        column_results = {}
        total_score = 0
        
        for column in columns:
            if column not in df.columns:
                column_results[column] = {'error': f"Column {column} not found"}
                continue
            
            # Check for null, empty string, and whitespace-only values
            complete_count = df.filter(
                F.col(column).isNotNull() & 
                (F.trim(F.col(column)) != "") &
                (F.col(column) != "")
            ).count()
            
            completeness_rate = (complete_count / total_records * 100) if total_records > 0 else 0
            
            column_results[column] = {
                'complete_count': complete_count,
                'incomplete_count': total_records - complete_count,
                'completeness_rate': round(completeness_rate, 2),
                'passed': completeness_rate >= threshold
            }
            
            total_score += completeness_rate
        
        avg_score = total_score / len([c for c in columns if c in df.columns])
        result['score'] = round(avg_score, 2)
        result['passed'] = avg_score >= threshold
        result['metrics'] = column_results
        
        return result
    
    def _apply_consistency_check(self, df: DataFrame, rule: Dict[str, Any], 
                                result: Dict[str, Any], total_records: int) -> Dict[str, Any]:
        """Apply consistency checks between related columns."""
        column1 = rule.get('column1')
        column2 = rule.get('column2')
        consistency_rule = rule.get('consistency_rule')  # e.g., 'column1 <= column2'
        threshold = rule.get('threshold', 95.0)
        
        if not all([column1, column2, consistency_rule]):
            result['error'] = "Missing required parameters for consistency check"
            return result
        
        if column1 not in df.columns or column2 not in df.columns:
            result['error'] = f"One or both columns not found: {column1}, {column2}"
            return result
        
        try:
            # Parse and apply consistency rule
            if consistency_rule == 'column1_le_column2':
                consistent_count = df.filter(F.col(column1) <= F.col(column2)).count()
            elif consistency_rule == 'column1_ge_column2':
                consistent_count = df.filter(F.col(column1) >= F.col(column2)).count()
            elif consistency_rule == 'column1_eq_column2':
                consistent_count = df.filter(F.col(column1) == F.col(column2)).count()
            else:
                result['error'] = f"Unknown consistency rule: {consistency_rule}"
                return result
            
            consistency_rate = (consistent_count / total_records * 100) if total_records > 0 else 0
            
            result['metrics'] = {
                'consistent_count': consistent_count,
                'inconsistent_count': total_records - consistent_count,
                'consistency_rate': round(consistency_rate, 2),
                'rule': consistency_rule
            }
            
            result['score'] = consistency_rate
            result['passed'] = consistency_rate >= threshold
            
        except Exception as e:
            result['error'] = f"Error applying consistency rule: {str(e)}"
        
        return result
    
    def _generate_quality_summary(self, quality_results: Dict[str, Any]) -> Dict[str, Any]:
        """Generate a comprehensive quality summary."""
        return {
            "overall_assessment": (
                "EXCELLENT" if quality_results["overall_score"] >= 95 else
                "GOOD" if quality_results["overall_score"] >= 85 else
                "FAIR" if quality_results["overall_score"] >= 70 else
                "POOR"
            ),
            "recommendations": self._generate_recommendations(quality_results),
            "risk_level": (
                "LOW" if quality_results["overall_score"] >= 90 else
                "MEDIUM" if quality_results["overall_score"] >= 75 else
                "HIGH"
            )
        }
    
    def _generate_recommendations(self, quality_results: Dict[str, Any]) -> List[str]:
        """Generate recommendations based on quality results."""
        recommendations = []
        
        for rule_result in quality_results.get("rule_results", []):
            if not rule_result.get("passed", True):
                rule_type = rule_result.get("rule_type")
                
                if rule_type == "null_check":
                    recommendations.append("Consider implementing data validation at source to reduce null values")
                elif rule_type == "uniqueness_check":
                    recommendations.append("Review data deduplication processes to improve uniqueness")
                elif rule_type == "range_check":
                    recommendations.append("Implement range validation during data ingestion")
                elif rule_type == "pattern_check":
                    recommendations.append("Consider standardizing data formats at source")
        
        if quality_results["overall_score"] < 80:
            recommendations.append("Overall data quality is below acceptable threshold - review data pipeline")
        
        return recommendations
