"""
Configuration for pytest fixtures used across test modules.
"""
import os
import sys
import pytest
from pyspark.sql import SparkSession
from unittest.mock import MagicMock

# Add the src directory to the Python path so we can import modules
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(__file__))))

@pytest.fixture(scope="session")
def spark_session():
    """
    Create a Spark session for testing.
    This is a session-scoped fixture that creates a local SparkSession for testing.
    """
    spark = (
        SparkSession.builder
        .master("local[*]")
        .appName("GlueETLPipelineTest")
        .config("spark.sql.warehouse.dir", "file:/tmp/spark-warehouse")
        .config("spark.sql.shuffle.partitions", "1")
        .config("spark.default.parallelism", "1")
        .config("spark.sql.sources.partitionOverwriteMode", "dynamic")
        .getOrCreate()
    )
    
    yield spark
    
    spark.stop()

@pytest.fixture
def glue_context(spark_session):
    """
    Create a mock GlueContext for testing.
    """
    # Create a mock GlueContext with the real SparkSession
    glue_context = MagicMock()
    glue_context.spark_session = spark_session
    
    # Add common GlueContext methods used in our jobs
    glue_context.create_dynamic_frame.from_catalog = MagicMock()
    glue_context.create_dynamic_frame.from_options = MagicMock()
    glue_context.purge_table = MagicMock()
    glue_context.write_dynamic_frame.from_options = MagicMock()
    
    return glue_context

@pytest.fixture
def aws_glue_job_context(glue_context):
    """
    Create a mock for the AWS Glue job context.
    """
    job_context = {
        "args": [
            {"JOB_NAME": "test_job"},
            {"ENVIRONMENT": "test"},
            {"DATABASE_NAME": "test_db"},
            {"SOURCE_TABLE": "test_source"},
            {"TARGET_TABLE": "test_target"},
            {"TEMP_DIR": "s3://test-bucket/temp/"},
            {"BOOKMARK_ENABLED": "true"}
        ]
    }
    
    return job_context

@pytest.fixture
def s3_mock():
    """
    Create a mock for S3 client.
    """
    s3_mock = MagicMock()
    s3_mock.list_objects_v2 = MagicMock()
    s3_mock.get_object = MagicMock()
    s3_mock.put_object = MagicMock()
    
    return s3_mock

@pytest.fixture
def dynamodb_mock():
    """
    Create a mock for DynamoDB client.
    """
    dynamodb_mock = MagicMock()
    dynamodb_mock.get_item = MagicMock()
    dynamodb_mock.put_item = MagicMock()
    dynamodb_mock.update_item = MagicMock()
    dynamodb_mock.query = MagicMock()
    
    return dynamodb_mock

@pytest.fixture
def sns_mock():
    """
    Create a mock for SNS client.
    """
    sns_mock = MagicMock()
    sns_mock.publish = MagicMock()
    
    return sns_mock

@pytest.fixture
def cloudwatch_mock():
    """
    Create a mock for CloudWatch client.
    """
    cloudwatch_mock = MagicMock()
    cloudwatch_mock.get_metric_data = MagicMock()
    cloudwatch_mock.put_metric_data = MagicMock()
    
    return cloudwatch_mock

@pytest.fixture
def glue_client_mock():
    """
    Create a mock for Glue client.
    """
    glue_mock = MagicMock()
    glue_mock.get_job_runs = MagicMock()
    glue_mock.get_job = MagicMock()
    glue_mock.start_job_run = MagicMock()
    glue_mock.get_table = MagicMock()
    
    return glue_mock

@pytest.fixture
def sample_data_path():
    """
    Return the path to the sample data directory.
    """
    return os.path.join(os.path.dirname(__file__), "sample_data")
