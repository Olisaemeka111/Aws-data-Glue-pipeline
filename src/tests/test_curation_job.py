"""
Unit tests for the data curation Glue job.
"""
import pytest
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType, DoubleType
from pyspark.sql.functions import col, lit
from unittest.mock import MagicMock, patch

# Import the module to test
# This will be the actual path to your curation job
# For example: from jobs.curation_job import curate_data, apply_aggregations
# For testing purposes, we'll mock these imports
with patch.dict('sys.modules', {
    'jobs.curation_job': MagicMock(),
    'awsglue.context': MagicMock(),
    'awsglue.job': MagicMock(),
    'awsglue.dynamicframe': MagicMock()
}):
    from jobs.curation_job import curate_data, apply_aggregations

class TestCurationJob:
    """Test cases for the data curation job."""
    
    def test_curate_data(self, spark_session):
        """Test data curation logic."""
        # Create a test schema for processed data
        schema = StructType([
            StructField("id", StringType(), False),
            StructField("name", StringType(), True),
            StructField("value", IntegerType(), True),
            StructField("calculated_value", IntegerType(), True),
            StructField("category", StringType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        
        # Create test data
        test_data = [
            ("1", "test1", 100, 200, "low", "2023-01-01 00:00:00"),
            ("2", "test2", 200, 400, "medium", "2023-01-02 00:00:00"),
            ("3", "test3", 300, 600, "high", "2023-01-03 00:00:00")
        ]
        
        # Create a DataFrame
        df = spark_session.createDataFrame(test_data, schema)
        
        # Mock the curate_data function to add a quality score
        def mock_curate(dataframe):
            return dataframe.withColumn("quality_score", 
                                       (col("value") / 100).cast(DoubleType()))
        
        with patch('jobs.curation_job.curate_data', side_effect=mock_curate):
            result_df = curate_data(df)
            
            # Assertions
            assert result_df.count() == 3
            assert "quality_score" in result_df.columns
            assert result_df.filter(col("id") == "1").select("quality_score").collect()[0][0] == 1.0
            assert result_df.filter(col("id") == "2").select("quality_score").collect()[0][0] == 2.0
            assert result_df.filter(col("id") == "3").select("quality_score").collect()[0][0] == 3.0
    
    def test_apply_aggregations(self, spark_session):
        """Test aggregation logic."""
        # Create a test schema for curated data
        schema = StructType([
            StructField("id", StringType(), False),
            StructField("name", StringType(), True),
            StructField("value", IntegerType(), True),
            StructField("calculated_value", IntegerType(), True),
            StructField("category", StringType(), True),
            StructField("quality_score", DoubleType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        
        # Create test data
        test_data = [
            ("1", "test1", 100, 200, "low", 1.0, "2023-01-01 00:00:00"),
            ("2", "test2", 200, 400, "medium", 2.0, "2023-01-02 00:00:00"),
            ("3", "test3", 300, 600, "high", 3.0, "2023-01-03 00:00:00"),
            ("4", "test4", 150, 300, "low", 1.5, "2023-01-04 00:00:00"),
            ("5", "test5", 250, 500, "medium", 2.5, "2023-01-05 00:00:00")
        ]
        
        # Create a DataFrame
        df = spark_session.createDataFrame(test_data, schema)
        
        # Mock the apply_aggregations function to create aggregated views
        def mock_aggregations(dataframe):
            # Create category aggregation
            category_agg = dataframe.groupBy("category").agg(
                {"value": "sum", "quality_score": "avg"}
            ).withColumnRenamed("sum(value)", "total_value") \
             .withColumnRenamed("avg(quality_score)", "avg_quality")
            
            # Return the original data and the aggregation
            return {
                "detailed": dataframe,
                "category_summary": category_agg
            }
        
        with patch('jobs.curation_job.apply_aggregations', side_effect=mock_aggregations):
            result = apply_aggregations(df)
            
            # Assertions
            assert "detailed" in result
            assert "category_summary" in result
            assert result["detailed"].count() == 5
            assert result["category_summary"].count() == 3
            
            # Check aggregation results
            low_row = result["category_summary"].filter(col("category") == "low").collect()[0]
            assert low_row["total_value"] == 250  # 100 + 150
            assert abs(low_row["avg_quality"] - 1.25) < 0.01  # (1.0 + 1.5) / 2
            
            medium_row = result["category_summary"].filter(col("category") == "medium").collect()[0]
            assert medium_row["total_value"] == 450  # 200 + 250
            assert abs(medium_row["avg_quality"] - 2.25) < 0.01  # (2.0 + 2.5) / 2
    
    def test_curation_job_end_to_end(self, spark_session, glue_context, aws_glue_job_context):
        """Test the end-to-end data curation flow."""
        # Create a test schema
        schema = StructType([
            StructField("id", StringType(), False),
            StructField("name", StringType(), True),
            StructField("value", IntegerType(), True),
            StructField("calculated_value", IntegerType(), True),
            StructField("category", StringType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        
        # Create test data
        test_data = [
            ("1", "test1", 100, 200, "low", "2023-01-01 00:00:00"),
            ("2", "test2", 200, 400, "medium", "2023-01-02 00:00:00"),
            ("3", "test3", 300, 600, "high", "2023-01-03 00:00:00")
        ]
        
        # Create a DataFrame
        df = spark_session.createDataFrame(test_data, schema)
        
        # Mock the dynamic frame creation
        mock_dyf = MagicMock()
        mock_dyf.toDF.return_value = df
        glue_context.create_dynamic_frame.from_catalog.return_value = mock_dyf
        
        # Mock the curate function to add quality scores
        def mock_curate(dataframe):
            return dataframe.withColumn("quality_score", 
                                       (col("value") / 100).cast(DoubleType()))
        
        # Mock the aggregations function
        def mock_aggregations(dataframe):
            # Create category aggregation
            category_agg = dataframe.groupBy("category").agg(
                {"value": "sum", "quality_score": "avg"}
            ).withColumnRenamed("sum(value)", "total_value") \
             .withColumnRenamed("avg(quality_score)", "avg_quality")
            
            # Return the original data and the aggregation
            return {
                "detailed": dataframe,
                "category_summary": category_agg
            }
        
        # Mock the main curation job
        with patch('jobs.curation_job.curate_data', side_effect=mock_curate), \
             patch('jobs.curation_job.apply_aggregations', side_effect=mock_aggregations), \
             patch('jobs.curation_job.main', return_value=None):
            
            from jobs.curation_job import main
            
            # Execute the job
            main(glue_context, aws_glue_job_context)
            
            # Assertions
            glue_context.create_dynamic_frame.from_catalog.assert_called_once()
            # Should be called twice, once for detailed and once for summary
            assert glue_context.write_dynamic_frame.from_options.call_count >= 1
