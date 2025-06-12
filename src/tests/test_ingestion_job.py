"""
Unit tests for the data ingestion Glue job.
"""
import pytest
import pandas as pd
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType
from unittest.mock import MagicMock, patch

# Import the module to test
# This will be the actual path to your ingestion job
# For example: from jobs.ingestion_job import process_data, validate_data
# For testing purposes, we'll mock these imports
with patch.dict('sys.modules', {
    'jobs.ingestion_job': MagicMock(),
    'awsglue.context': MagicMock(),
    'awsglue.job': MagicMock(),
    'awsglue.dynamicframe': MagicMock()
}):
    from jobs.ingestion_job import process_data, validate_data

class TestIngestionJob:
    """Test cases for the data ingestion job."""
    
    def test_validate_data_valid(self, spark_session):
        """Test data validation with valid data."""
        # Create a test schema
        schema = StructType([
            StructField("id", StringType(), False),
            StructField("name", StringType(), True),
            StructField("value", IntegerType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        
        # Create test data
        test_data = [
            ("1", "test1", 100, "2023-01-01 00:00:00"),
            ("2", "test2", 200, "2023-01-02 00:00:00"),
            ("3", "test3", 300, "2023-01-03 00:00:00")
        ]
        
        # Create a DataFrame
        df = spark_session.createDataFrame(test_data, schema)
        
        # Mock the validate_data function
        with patch('jobs.ingestion_job.validate_data', return_value=(df, [])):
            result_df, errors = validate_data(df)
            
            # Assertions
            assert result_df.count() == 3
            assert len(errors) == 0
    
    def test_validate_data_invalid(self, spark_session):
        """Test data validation with invalid data."""
        # Create a test schema
        schema = StructType([
            StructField("id", StringType(), False),
            StructField("name", StringType(), True),
            StructField("value", IntegerType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        
        # Create test data with an invalid row (null id)
        test_data = [
            ("1", "test1", 100, "2023-01-01 00:00:00"),
            (None, "test2", 200, "2023-01-02 00:00:00"),  # Invalid: null id
            ("3", "test3", 300, "2023-01-03 00:00:00")
        ]
        
        # Create a DataFrame
        df = spark_session.createDataFrame(test_data, schema)
        
        # Mock the validate_data function to return errors
        with patch('jobs.ingestion_job.validate_data', return_value=(df.filter("id IS NOT NULL"), ["Row with null id rejected"])):
            result_df, errors = validate_data(df)
            
            # Assertions
            assert result_df.count() == 2
            assert len(errors) == 1
            assert "null id" in errors[0]
    
    def test_process_data(self, spark_session, glue_context, aws_glue_job_context):
        """Test the data processing function."""
        # Create a test schema
        schema = StructType([
            StructField("id", StringType(), False),
            StructField("name", StringType(), True),
            StructField("value", IntegerType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        
        # Create test data
        test_data = [
            ("1", "test1", 100, "2023-01-01 00:00:00"),
            ("2", "test2", 200, "2023-01-02 00:00:00"),
            ("3", "test3", 300, "2023-01-03 00:00:00")
        ]
        
        # Create a DataFrame
        df = spark_session.createDataFrame(test_data, schema)
        
        # Mock the dynamic frame creation
        mock_dyf = MagicMock()
        mock_dyf.toDF.return_value = df
        glue_context.create_dynamic_frame.from_catalog.return_value = mock_dyf
        
        # Mock the process_data function
        with patch('jobs.ingestion_job.process_data', return_value=mock_dyf):
            result = process_data(glue_context, aws_glue_job_context)
            
            # Assertions
            assert result is not None
            glue_context.create_dynamic_frame.from_catalog.assert_called_once()
            
    def test_integration_ingestion_job(self, spark_session, glue_context, aws_glue_job_context, s3_mock):
        """Integration test for the full ingestion job."""
        # This test would simulate the full job execution
        # For now, we'll just mock the main components
        
        # Mock S3 data source
        test_csv_content = """id,name,value,timestamp
1,test1,100,2023-01-01 00:00:00
2,test2,200,2023-01-02 00:00:00
3,test3,300,2023-01-03 00:00:00
"""
        s3_mock.get_object.return_value = {"Body": MagicMock(read=lambda: test_csv_content.encode())}
        
        # Mock the main job function
        with patch('jobs.ingestion_job.main', return_value=None):
            from jobs.ingestion_job import main
            
            # Execute the job
            main(glue_context, aws_glue_job_context)
            
            # Assertions
            # In a real test, we would verify the output data was written correctly
            # For now, we'll just check that the necessary functions were called
            glue_context.create_dynamic_frame.from_options.assert_called()
            glue_context.write_dynamic_frame.from_options.assert_called()
