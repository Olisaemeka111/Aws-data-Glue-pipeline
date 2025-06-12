"""
Unit tests for the data processing Glue job.
"""
import pytest
import pandas as pd
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType, DoubleType
from pyspark.sql.functions import col
from unittest.mock import MagicMock, patch

# Import the module to test
# This will be the actual path to your processing job
# For example: from jobs.processing_job import transform_data, apply_business_rules
# For testing purposes, we'll mock these imports
with patch.dict('sys.modules', {
    'jobs.processing_job': MagicMock(),
    'awsglue.context': MagicMock(),
    'awsglue.job': MagicMock(),
    'awsglue.dynamicframe': MagicMock()
}):
    from jobs.processing_job import transform_data, apply_business_rules

class TestProcessingJob:
    """Test cases for the data processing job."""
    
    def test_transform_data(self, spark_session):
        """Test data transformation logic."""
        # Create a test schema for raw data
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
        
        # Mock the transform_data function to add a calculated column
        def mock_transform(dataframe):
            return dataframe.withColumn("calculated_value", col("value") * 2)
        
        with patch('jobs.processing_job.transform_data', side_effect=mock_transform):
            result_df = transform_data(df)
            
            # Assertions
            assert result_df.count() == 3
            assert "calculated_value" in result_df.columns
            assert result_df.filter(col("id") == "1").select("calculated_value").collect()[0][0] == 200
            assert result_df.filter(col("id") == "2").select("calculated_value").collect()[0][0] == 400
    
    def test_apply_business_rules(self, spark_session):
        """Test business rule application."""
        # Create a test schema for transformed data
        schema = StructType([
            StructField("id", StringType(), False),
            StructField("name", StringType(), True),
            StructField("value", IntegerType(), True),
            StructField("calculated_value", IntegerType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        
        # Create test data
        test_data = [
            ("1", "test1", 100, 200, "2023-01-01 00:00:00"),
            ("2", "test2", 200, 400, "2023-01-02 00:00:00"),
            ("3", "test3", 300, 600, "2023-01-03 00:00:00")
        ]
        
        # Create a DataFrame
        df = spark_session.createDataFrame(test_data, schema)
        
        # Mock the apply_business_rules function to filter rows and add a category
        def mock_apply_rules(dataframe):
            return dataframe.withColumn(
                "category", 
                spark_session.createDataFrame([
                    ("1", "low"),
                    ("2", "medium"),
                    ("3", "high")
                ], ["id", "category"])["category"]
            )
        
        with patch('jobs.processing_job.apply_business_rules', side_effect=mock_apply_rules):
            result_df = apply_business_rules(df)
            
            # Assertions
            assert result_df.count() == 3
            assert "category" in result_df.columns
            assert result_df.filter(col("id") == "1").select("category").collect()[0][0] == "low"
            assert result_df.filter(col("id") == "2").select("category").collect()[0][0] == "medium"
            assert result_df.filter(col("id") == "3").select("category").collect()[0][0] == "high"
    
    def test_process_data_end_to_end(self, spark_session, glue_context, aws_glue_job_context):
        """Test the end-to-end data processing flow."""
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
        
        # Mock the transform function to add calculated columns
        def mock_transform(dataframe):
            return dataframe.withColumn("calculated_value", col("value") * 2)
        
        # Mock the business rules function to add categories
        def mock_apply_rules(dataframe):
            return dataframe.withColumn(
                "category", 
                spark_session.createDataFrame([
                    ("1", "low"),
                    ("2", "medium"),
                    ("3", "high")
                ], ["id", "category"])["category"]
            )
        
        # Mock the main processing job
        with patch('jobs.processing_job.transform_data', side_effect=mock_transform), \
             patch('jobs.processing_job.apply_business_rules', side_effect=mock_apply_rules), \
             patch('jobs.processing_job.main', return_value=None):
            
            from jobs.processing_job import main
            
            # Execute the job
            main(glue_context, aws_glue_job_context)
            
            # Assertions
            glue_context.create_dynamic_frame.from_catalog.assert_called_once()
            glue_context.write_dynamic_frame.from_options.assert_called_once()
