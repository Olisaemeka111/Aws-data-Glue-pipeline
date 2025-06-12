import os
import sys
import unittest
import boto3
import pandas as pd
from unittest.mock import patch, MagicMock
from pyspark.sql import SparkSession
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame

# Add src directory to path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
from jobs.data_ingestion import process_source_data, update_job_state
from jobs.data_processing import apply_transformations
from jobs.data_quality import perform_data_quality_checks
from utils.glue_utils import GlueJobUtils, DataQualityChecker

class TestGlueJobs(unittest.TestCase):
    """Test suite for AWS Glue ETL jobs."""
    
    @classmethod
    def setUpClass(cls):
        """Set up test environment."""
        # Create a local Spark session for testing
        cls.spark = SparkSession.builder \
            .appName("GlueJobsTest") \
            .master("local[*]") \
            .getOrCreate()
        
        # Create a mock GlueContext
        sc = SparkContext.getOrCreate()
        cls.glue_context = MagicMock(spec=GlueContext)
        cls.glue_context.spark_session = cls.spark
        
        # Sample test data
        data = [
            {"id": "1", "customer_id": "C001", "transaction_date": "2023-01-01", "amount": "100.00"},
            {"id": "2", "customer_id": "C002", "transaction_date": "2023-01-01", "amount": "200.00"},
            {"id": "3", "customer_id": "C003", "transaction_date": "2023-01-01", "amount": "300.00"},
            {"id": "4", "customer_id": "C004", "transaction_date": "2023-01-01", "amount": "400.00"},
            {"id": "5", "customer_id": "C005", "transaction_date": "2023-01-01", "amount": "500.00"},
        ]
        cls.test_df = cls.spark.createDataFrame(data)
        cls.test_dynamic_frame = DynamicFrame.fromDF(cls.test_df, cls.glue_context, "test_dynamic_frame")
    
    @classmethod
    def tearDownClass(cls):
        """Clean up resources."""
        cls.spark.stop()
    
    @patch('boto3.client')
    def test_update_job_state(self, mock_boto3_client):
        """Test update_job_state function."""
        # Setup mock
        mock_dynamodb = MagicMock()
        mock_boto3_client.return_value = mock_dynamodb
        
        # Call function
        update_job_state(
            mock_dynamodb,
            "test-table",
            "test-job",
            "RUNNING",
            message="Test message",
            metadata={"test": "metadata"}
        )
        
        # Assert
        mock_dynamodb.put_item.assert_called_once()
        args, kwargs = mock_dynamodb.put_item.call_args
        self.assertEqual(kwargs['TableName'], "test-table")
        self.assertEqual(kwargs['Item']['job_name'], {'S': 'test-job'})
        self.assertEqual(kwargs['Item']['status'], {'S': 'RUNNING'})
        self.assertEqual(kwargs['Item']['message'], {'S': 'Test message'})
    
    @patch('jobs.data_ingestion.glueContext')
    def test_process_source_data(self, mock_glue_context):
        """Test process_source_data function."""
        # Setup mock
        mock_glue_context.create_dynamic_frame.from_options.return_value = self.test_dynamic_frame
        mock_glue_context.write_dynamic_frame.from_options.return_value = None
        
        # Call function
        with patch('jobs.data_ingestion.logger'):
            result = process_source_data(
                mock_glue_context,
                self.spark,
                "test-raw-bucket",
                "test/path",
                "test-processed-bucket",
                "test/output"
            )
        
        # Assert
        self.assertEqual(result, 5)  # 5 records in test data
        mock_glue_context.create_dynamic_frame.from_options.assert_called_once()
        mock_glue_context.write_dynamic_frame.from_options.assert_called_once()
    
    def test_apply_transformations(self):
        """Test apply_transformations function."""
        # Setup
        mock_glue_context = MagicMock()
        mock_glue_context.spark_session = self.spark
        
        # Call function
        with patch('jobs.data_processing.logger'):
            result = apply_transformations(mock_glue_context, self.test_dynamic_frame)
        
        # Assert
        self.assertIsNotNone(result)
        result_df = result.toDF()
        self.assertTrue("processing_timestamp" in result_df.columns)
        self.assertTrue("data_lineage" in result_df.columns)
        self.assertEqual(result_df.count(), 5)
    
    def test_perform_data_quality_checks(self):
        """Test perform_data_quality_checks function."""
        # Setup
        mock_glue_context = MagicMock()
        mock_glue_context.spark_session = self.spark
        
        # Define quality rules
        quality_rules = [
            {
                'id': 'rule_001',
                'name': 'Check for null values in key columns',
                'type': 'null_check',
                'columns': ['id', 'customer_id'],
                'threshold': 1.0
            },
            {
                'id': 'rule_002',
                'name': 'Check uniqueness of primary keys',
                'type': 'uniqueness_check',
                'columns': ['id'],
                'threshold': 99.9
            }
        ]
        
        # Call function
        with patch('jobs.data_quality.logger'):
            overall_passed, results = perform_data_quality_checks(
                mock_glue_context,
                self.test_dynamic_frame,
                quality_rules
            )
        
        # Assert
        self.assertTrue(overall_passed)
        self.assertEqual(len(results), 2)
        self.assertTrue(results[0]['passed'])
        self.assertTrue(results[1]['passed'])
    
    def test_glue_job_utils(self):
        """Test GlueJobUtils class."""
        # Setup
        mock_glue_context = MagicMock()
        mock_glue_context.spark_session = self.spark
        
        # Create utils instance
        utils = GlueJobUtils(mock_glue_context, "test-job", "test-table")
        
        # Test add_audit_columns
        with patch.object(utils, 'dynamodb'):
            result = utils.add_audit_columns(self.test_dynamic_frame, "test-batch")
            
            # Assert
            result_df = result.toDF()
            self.assertTrue("processing_timestamp" in result_df.columns)
            self.assertTrue("batch_id" in result_df.columns)
            self.assertTrue("job_name" in result_df.columns)
            self.assertEqual(result_df.count(), 5)
    
    def test_data_quality_checker(self):
        """Test DataQualityChecker class."""
        # Setup
        mock_glue_context = MagicMock()
        mock_glue_context.spark_session = self.spark
        
        # Create checker instance
        checker = DataQualityChecker(mock_glue_context)
        
        # Define quality rules
        quality_rules = [
            {
                'id': 'rule_001',
                'name': 'Check for null values in key columns',
                'type': 'null_check',
                'columns': ['id', 'customer_id'],
                'threshold': 1.0
            }
        ]
        
        # Test run_quality_checks
        overall_passed, results = checker.run_quality_checks(
            self.test_dynamic_frame,
            quality_rules
        )
        
        # Assert
        self.assertTrue(overall_passed)
        self.assertEqual(len(results), 1)
        self.assertTrue(results[0]['passed'])
        self.assertEqual(results[0]['rule_id'], 'rule_001')
        self.assertTrue('id' in results[0]['metrics'])
        self.assertTrue('customer_id' in results[0]['metrics'])


if __name__ == '__main__':
    unittest.main()
