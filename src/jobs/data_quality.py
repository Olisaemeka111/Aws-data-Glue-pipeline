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
from pyspark.sql.types import *
import datetime
import uuid
import json
import logging
import os

# Import our enhanced utilities
sys.path.append('/opt/aws-glue-libs/PyGlue.zip/dependencies')
from utils.glue_utils import GlueJobUtils, DataQualityChecker, DataQualityError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

class DataQualityJobError(Exception):
    """Custom exception for data quality job errors."""
    pass

def get_job_metadata() -> Dict[str, str]:
    """Get job metadata from job parameters."""
    try:
        args = getResolvedOptions(sys.argv, [
            'JOB_NAME', 
            'curated_bucket', 
            'environment',
            'state_table',
            'sns_topic_arn',
            'quality_rules_s3_path',
            'fail_on_quality_issues'
        ])
        return args
    except Exception as e:
        logger.error(f"Error parsing job arguments: {str(e)}")
        raise DataQualityJobError(f"Failed to parse job arguments: {str(e)}")

def initialize_spark_context():
    """Initialize Spark and Glue contexts with optimized configuration."""
    try:
        sc = SparkContext()
        sc.setLogLevel("WARN")
        
        glueContext = GlueContext(sc)
        spark = glueContext.spark_session
        
        # Optimize Spark configuration for data quality checks
        spark.conf.set("spark.sql.adaptive.enabled", "true")
        spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
        spark.conf.set("spark.sql.parquet.enableVectorizedReader", "true")
        spark.conf.set("spark.sql.execution.arrow.pyspark.enabled", "true")
        
        job = Job(glueContext)
        return sc, glueContext, spark, job
    except Exception as e:
        logger.error(f"Error initializing Spark context: {str(e)}")
        raise DataQualityJobError(f"Failed to initialize Spark context: {str(e)}")

def load_quality_rules(job_utils: GlueJobUtils, rules_s3_path: Optional[str] = None) -> List[Dict[str, Any]]:
    """Load data quality rules from S3 or use default rules."""
    
    # Default quality rules if none provided
    default_rules = [
        {
            "id": "null_check_001",
            "name": "Critical Fields Null Check",
            "type": "null_check",
            "columns": ["id", "created_date"],
            "threshold": 99.0,
            "description": "Check that critical fields are not null",
            "severity": "critical"
        },
        {
            "id": "uniqueness_check_001", 
            "name": "ID Uniqueness Check",
            "type": "uniqueness_check",
            "columns": ["id"],
            "threshold": 100.0,
            "description": "Check that ID field is unique",
            "severity": "critical"
        },
        {
            "id": "completeness_check_001",
            "name": "Data Completeness Check", 
            "type": "completeness_check",
            "columns": ["name", "email", "status"],
            "threshold": 95.0,
            "description": "Check that important fields are complete",
            "severity": "major"
        },
        {
            "id": "pattern_check_001",
            "name": "Email Format Check",
            "type": "pattern_check", 
            "column": "email",
            "pattern": r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
            "threshold": 98.0,
            "description": "Check that email follows valid format",
            "severity": "major"
        },
        {
            "id": "range_check_001",
            "name": "Age Range Check",
            "type": "range_check",
            "column": "age", 
            "min_value": 0,
            "max_value": 150,
            "threshold": 99.0,
            "description": "Check that age is within reasonable range",
            "severity": "major"
        },
        {
            "id": "consistency_check_001",
            "name": "Date Consistency Check",
            "type": "consistency_check",
            "column1": "created_date",
            "column2": "updated_date", 
            "consistency_rule": "column1_le_column2",
            "threshold": 99.0,
            "description": "Check that created_date <= updated_date",
            "severity": "major"
        }
    ]
    
    if not rules_s3_path:
        logger.info("No rules S3 path provided, using default rules")
        return default_rules
    
    try:
        # Parse S3 path
        if rules_s3_path.startswith('s3://'):
            path_parts = rules_s3_path[5:].split('/', 1)
            bucket = path_parts[0]
            key = path_parts[1] if len(path_parts) > 1 else 'quality_rules.json'
        else:
            raise ValueError("Invalid S3 path format")
        
        # Try to load rules from S3
        s3_client = boto3.client('s3')
        
        try:
            response = s3_client.get_object(Bucket=bucket, Key=key)
            rules_content = response['Body'].read().decode('utf-8')
            custom_rules = json.loads(rules_content)
            
            # Validate rules format
            if isinstance(custom_rules, list):
                logger.info(f"Loaded {len(custom_rules)} custom quality rules from S3")
                return custom_rules
            else:
                logger.warning("Invalid rules format in S3, using default rules")
                return default_rules
                
        except s3_client.exceptions.NoSuchKey:
            logger.warning(f"Quality rules file not found at {rules_s3_path}, using default rules")
            return default_rules
            
    except Exception as e:
        logger.error(f"Error loading quality rules from S3: {str(e)}")
        logger.info("Falling back to default quality rules")
        return default_rules

def get_data_for_quality_check(job_utils: GlueJobUtils, curated_bucket: str, 
                              source_path: str) -> Optional[DynamicFrame]:
    """Get the data for quality checks with enhanced validation."""
    try:
        logger.info(f"Loading data for quality checks from s3://{curated_bucket}/{source_path}")
        
        # Use enhanced read function from job_utils
        dynamic_frame = job_utils.read_from_s3(
            bucket=curated_bucket,
            path=source_path,
            format="parquet",
            options={"optimizePerformance": True}
        )
        
        if not dynamic_frame:
            logger.warning("No data found for quality checks")
            return None
            
        record_count = dynamic_frame.count()
        logger.info(f"Loaded {record_count:,} records for quality validation")
        
        return dynamic_frame
        
    except Exception as e:
        logger.error(f"Error loading data for quality checks: {str(e)}")
        raise DataQualityJobError(f"Failed to load data for quality checks: {str(e)}")

def generate_quality_report(quality_results: Dict[str, Any], job_name: str, 
                           environment: str) -> str:
    """Generate a comprehensive quality report."""
    
    report_lines = []
    report_lines.append("=" * 80)
    report_lines.append("DATA QUALITY ASSESSMENT REPORT")
    report_lines.append("=" * 80)
    report_lines.append(f"Job Name: {job_name}")
    report_lines.append(f"Environment: {environment}")
    report_lines.append(f"Timestamp: {datetime.datetime.now().isoformat()}")
    report_lines.append(f"Total Records Analyzed: {quality_results.get('total_records', 0):,}")
    report_lines.append("")
    
    # Overall Summary
    report_lines.append("OVERALL SUMMARY")
    report_lines.append("-" * 40)
    overall_score = quality_results.get('overall_score', 0)
    report_lines.append(f"Overall Quality Score: {overall_score:.1f}%")
    report_lines.append(f"Rules Passed: {quality_results.get('passed_rules', 0)}")
    report_lines.append(f"Rules Failed: {quality_results.get('failed_rules', 0)}")
    
    summary = quality_results.get('summary', {})
    if summary:
        report_lines.append(f"Assessment: {summary.get('overall_assessment', 'Unknown')}")
        report_lines.append(f"Risk Level: {summary.get('risk_level', 'Unknown')}")
    
    report_lines.append("")
    
    # Detailed Rule Results
    report_lines.append("DETAILED RULE RESULTS")
    report_lines.append("-" * 40)
    
    rule_results = quality_results.get('rule_results', [])
    for rule_result in rule_results:
        rule_name = rule_result.get('rule_name', 'Unknown Rule')
        rule_type = rule_result.get('rule_type', 'Unknown Type')
        passed = rule_result.get('passed', False)
        score = rule_result.get('score', 0)
        
        status_icon = "✓" if passed else "✗"
        report_lines.append(f"{status_icon} {rule_name} ({rule_type})")
        report_lines.append(f"   Score: {score:.1f}%")
        
        if 'error' in rule_result:
            report_lines.append(f"   Error: {rule_result['error']}")
        else:
            metrics = rule_result.get('metrics', {})
            if metrics:
                report_lines.append("   Metrics:")
                for key, value in metrics.items():
                    if isinstance(value, dict):
                        if 'error' not in value:
                            report_lines.append(f"     {key}: {value}")
                    else:
                        report_lines.append(f"     {key}: {value}")
        
        report_lines.append("")
    
    # Recommendations
    recommendations = summary.get('recommendations', [])
    if recommendations:
        report_lines.append("RECOMMENDATIONS")
        report_lines.append("-" * 40)
        for i, recommendation in enumerate(recommendations, 1):
            report_lines.append(f"{i}. {recommendation}")
        report_lines.append("")
    
    # Data Profile Summary
    if 'data_profile' in quality_results:
        profile = quality_results['data_profile']
        report_lines.append("DATA PROFILE SUMMARY")
        report_lines.append("-" * 40)
        report_lines.append(f"Total Columns: {profile.get('total_columns', 0)}")
        report_lines.append(f"Numeric Columns: {len(profile.get('numeric_columns', []))}")
        report_lines.append(f"String Columns: {len(profile.get('string_columns', []))}")
        report_lines.append(f"Date Columns: {len(profile.get('date_columns', []))}")
        report_lines.append("")
    
    report_lines.append("=" * 80)
    
    return "\n".join(report_lines)

def save_quality_report(job_utils: GlueJobUtils, report_content: str, 
                       curated_bucket: str, report_path: str) -> None:
    """Save quality report to S3."""
    try:
        # Convert report to DataFrame and then DynamicFrame
        spark = job_utils.glue_context.spark_session
        
        # Create a simple DataFrame with the report content
        report_data = [(report_content, datetime.datetime.now().isoformat())]
        report_df = spark.createDataFrame(report_data, ["report_content", "generated_timestamp"])
        
        # Convert to DynamicFrame
        report_dynamic_frame = DynamicFrame.fromDF(report_df, job_utils.glue_context, "quality_report")
        
        # Write to S3
        job_utils.write_to_s3(
            dynamic_frame=report_dynamic_frame,
            bucket=curated_bucket,
            path=report_path,
            format="json",
            write_mode="overwrite"
        )
        
        logger.info(f"Quality report saved to s3://{curated_bucket}/{report_path}")
        
    except Exception as e:
        logger.error(f"Error saving quality report: {str(e)}")

def profile_data(dynamic_frame: DynamicFrame) -> Dict[str, Any]:
    """Generate basic data profiling information."""
    try:
        df = dynamic_frame.toDF()
        
        profile = {
            'total_columns': len(df.columns),
            'total_records': df.count(),
            'numeric_columns': [],
            'string_columns': [],
            'date_columns': [],
            'column_stats': {}
        }
        
        # Categorize columns by type and collect basic stats
        for field in df.schema.fields:
            column_name = field.name
            column_type = field.dataType
            
            if isinstance(column_type, (IntegerType, LongType, DoubleType, FloatType)):
                profile['numeric_columns'].append(column_name)
                
                # Get basic numeric stats
                stats = df.select(
                    F.min(column_name).alias('min'),
                    F.max(column_name).alias('max'),
                    F.mean(column_name).alias('mean'),
                    F.stddev(column_name).alias('stddev'),
                    F.count(F.when(F.col(column_name).isNull(), 1)).alias('null_count')
                ).collect()[0]
                
                profile['column_stats'][column_name] = {
                    'type': 'numeric',
                    'min': float(stats['min']) if stats['min'] is not None else None,
                    'max': float(stats['max']) if stats['max'] is not None else None,
                    'mean': float(stats['mean']) if stats['mean'] is not None else None,
                    'stddev': float(stats['stddev']) if stats['stddev'] is not None else None,
                    'null_count': stats['null_count']
                }
                
            elif isinstance(column_type, StringType):
                profile['string_columns'].append(column_name)
                
                # Get basic string stats
                stats = df.select(
                    F.min(F.length(column_name)).alias('min_length'),
                    F.max(F.length(column_name)).alias('max_length'),
                    F.mean(F.length(column_name)).alias('avg_length'),
                    F.count(F.when(F.col(column_name).isNull(), 1)).alias('null_count'),
                    F.countDistinct(column_name).alias('distinct_count')
                ).collect()[0]
                
                profile['column_stats'][column_name] = {
                    'type': 'string',
                    'min_length': stats['min_length'],
                    'max_length': stats['max_length'],
                    'avg_length': float(stats['avg_length']) if stats['avg_length'] is not None else None,
                    'null_count': stats['null_count'],
                    'distinct_count': stats['distinct_count']
                }
                
            elif isinstance(column_type, (DateType, TimestampType)):
                profile['date_columns'].append(column_name)
                
                # Get basic date stats
                stats = df.select(
                    F.min(column_name).alias('min_date'),
                    F.max(column_name).alias('max_date'),
                    F.count(F.when(F.col(column_name).isNull(), 1)).alias('null_count')
                ).collect()[0]
                
                profile['column_stats'][column_name] = {
                    'type': 'date',
                    'min_date': str(stats['min_date']) if stats['min_date'] is not None else None,
                    'max_date': str(stats['max_date']) if stats['max_date'] is not None else None,
                    'null_count': stats['null_count']
                }
        
        return profile
        
    except Exception as e:
        logger.error(f"Error profiling data: {str(e)}")
        return {'error': str(e)}

def main():
    """Main data quality validation function."""
    start_time = datetime.datetime.now()
    
    # Get job parameters
    try:
        args = get_job_metadata()
        job_name = args['JOB_NAME']
        curated_bucket = args['curated_bucket']
        environment = args['environment']
        state_table = args['state_table']
        sns_topic_arn = args['sns_topic_arn']
        quality_rules_s3_path = args.get('quality_rules_s3_path')
        fail_on_quality_issues = args.get('fail_on_quality_issues', 'false').lower() == 'true'
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
    
    # Initialize utility classes
    try:
        job_utils = GlueJobUtils(glueContext, job_name, state_table, environment)
        quality_checker = DataQualityChecker(glueContext, job_utils)
    except Exception as e:
        logger.error(f"Failed to initialize utility classes: {str(e)}")
        return
    
    quality_results = {}
    
    try:
        # Update job state to RUNNING
        job_utils.update_job_state('RUNNING', message="Data quality job started")
        
        # Calculate date partitions
        today = datetime.datetime.now()
        year = today.strftime("%Y")
        month = today.strftime("%m") 
        day = today.strftime("%d")
        
        # Define source path for curated data
        source_path = f"curated/{year}/{month}/{day}/"
        
        logger.info(f"Running quality checks on data from {source_path}")
        
        # Load quality rules
        quality_rules = load_quality_rules(job_utils, quality_rules_s3_path)
        logger.info(f"Loaded {len(quality_rules)} quality rules")
        
        # Get data for quality checks
        curated_data = get_data_for_quality_check(job_utils, curated_bucket, source_path)
        
        if not curated_data:
            message = "No curated data found for quality validation"
            logger.warning(message)
            job_utils.update_job_state('SUCCEEDED', message=message, 
                                     metadata={'records_analyzed': 0, 'rules_executed': 0})
            
            # Send notification
            if sns_topic_arn:
                job_utils.send_notification(
                    sns_topic_arn, 
                    f"No Data - {job_name}",
                    f"Data Quality Job: {job_name}\nStatus: No data to validate\nEnvironment: {environment}"
                )
            
            job.commit()
            return
        
        # Profile the data
        logger.info("Generating data profile...")
        data_profile = profile_data(curated_data)
        
        # Run quality checks
        logger.info("Running comprehensive quality checks...")
        quality_results = quality_checker.run_quality_checks(
            dynamic_frame=curated_data,
            quality_rules=quality_rules,
            fail_on_error=fail_on_quality_issues
        )
        
        # Add data profile to results
        quality_results['data_profile'] = data_profile
        
        # Calculate processing duration
        end_time = datetime.datetime.now()
        processing_duration = (end_time - start_time).total_seconds()
        
        # Generate comprehensive report
        quality_report = generate_quality_report(quality_results, job_name, environment)
        
        # Save quality report to S3
        report_path = f"quality_reports/{year}/{month}/{day}/quality_report_{job_name}_{int(start_time.timestamp())}.json"
        save_quality_report(job_utils, quality_report, curated_bucket, report_path)
        
        # Determine job status based on quality results
        overall_score = quality_results.get('overall_score', 0)
        failed_rules = quality_results.get('failed_rules', 0)
        
        if overall_score >= 90:
            status = 'SUCCEEDED'
            status_message = f"Data quality validation passed with score: {overall_score:.1f}%"
        elif overall_score >= 75:
            status = 'SUCCEEDED_WITH_WARNINGS'
            status_message = f"Data quality validation completed with warnings. Score: {overall_score:.1f}%"
        else:
            status = 'FAILED' if fail_on_quality_issues else 'SUCCEEDED_WITH_WARNINGS'
            status_message = f"Data quality validation failed. Score: {overall_score:.1f}%"
        
        # Prepare metadata
        metadata = {
            'overall_score': overall_score,
            'rules_passed': quality_results.get('passed_rules', 0),
            'rules_failed': failed_rules,
            'total_rules': quality_results.get('total_rules', 0),
            'records_analyzed': quality_results.get('total_records', 0),
            'processing_duration_seconds': processing_duration,
            'report_location': f"s3://{curated_bucket}/{report_path}",
            'assessment': quality_results.get('summary', {}).get('overall_assessment', 'Unknown'),
            'risk_level': quality_results.get('summary', {}).get('risk_level', 'Unknown')
        }
        
        # Update job state
        job_utils.update_job_state(status, message=status_message, metadata=metadata)
        
        # Send detailed notification
        if sns_topic_arn:
            notification_message = f"""
Data Quality Validation Completed

Job: {job_name}
Environment: {environment}
Status: {status}

Quality Metrics:
- Overall Score: {overall_score:.1f}%
- Rules Passed: {quality_results.get('passed_rules', 0)}/{quality_results.get('total_rules', 0)}
- Records Analyzed: {quality_results.get('total_records', 0):,}
- Assessment: {quality_results.get('summary', {}).get('overall_assessment', 'Unknown')}
- Risk Level: {quality_results.get('summary', {}).get('risk_level', 'Unknown')}

Processing Duration: {processing_duration:.2f} seconds
Report Location: s3://{curated_bucket}/{report_path}

{status_message}
"""
            
            # Add message attributes for filtering
            message_attributes = {
                'JobName': job_name,
                'Environment': environment,
                'QualityScore': overall_score,
                'Status': status,
                'RiskLevel': quality_results.get('summary', {}).get('risk_level', 'Unknown')
            }
            
            job_utils.send_notification(
                sns_topic_arn,
                f"{status} - Data Quality - {job_name}",
                notification_message,
                message_attributes
            )
        
        logger.info(f"Data quality validation completed. Score: {overall_score:.1f}%")
        
        # Commit the job
        job.commit()
        
    except DataQualityError as e:
        # Handle data quality specific errors
        error_message = str(e)
        logger.error(f"Data quality error: {error_message}")
        
        job_utils.update_job_state('FAILED', message=error_message,
                                 metadata={'error_type': 'DataQualityError',
                                         'overall_score': quality_results.get('overall_score', 0)})
        
        if sns_topic_arn:
            failure_message = f"""
Data Quality Validation Failed

Job: {job_name}
Environment: {environment}
Error: {error_message}
Error Type: Data Quality Error

Overall Score: {quality_results.get('overall_score', 0):.1f}%
"""
            job_utils.send_notification(sns_topic_arn, f"FAILED - Data Quality - {job_name}", 
                                      failure_message)
        
        if fail_on_quality_issues:
            raise
        
    except DataQualityJobError as e:
        # Handle job-specific errors
        error_message = str(e)
        logger.error(f"Data quality job error: {error_message}")
        
        job_utils.update_job_state('FAILED', message=error_message,
                                 metadata={'error_type': 'DataQualityJobError'})
        
        if sns_topic_arn:
            failure_message = f"""
Data Quality Job Failed

Job: {job_name}
Environment: {environment}
Error: {error_message}
Error Type: Job Configuration Error
"""
            job_utils.send_notification(sns_topic_arn, f"FAILED - Data Quality - {job_name}", 
                                      failure_message)
        
        raise
        
    except Exception as e:
        # Handle unexpected errors
        error_message = f"Unexpected error: {str(e)}"
        logger.error(error_message)
        
        job_utils.update_job_state('FAILED', message=error_message,
                                 metadata={'error_type': 'UnexpectedError'})
        
        if sns_topic_arn:
            failure_message = f"""
Data Quality Job Failed - Unexpected Error

Job: {job_name}
Environment: {environment}
Error: {error_message}
Error Type: System Error
"""
            job_utils.send_notification(sns_topic_arn, f"CRITICAL FAILURE - Data Quality - {job_name}", 
                                      failure_message)
        
        raise

if __name__ == "__main__":
    main()
