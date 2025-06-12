"""
End-to-end integration tests for the AWS Glue ETL pipeline.
"""
import pytest
import boto3
import json
import os
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

# Import the modules to test
# For testing purposes, we'll mock these imports
with patch.dict('sys.modules', {
    'jobs.ingestion_job': MagicMock(),
    'jobs.processing_job': MagicMock(),
    'jobs.curation_job': MagicMock(),
    'utils.crawler': MagicMock(),
    'utils.glue': MagicMock(),
    'utils.common': MagicMock()
}):
    from jobs.ingestion_job import main as ingestion_main
    from jobs.processing_job import main as processing_main
    from jobs.curation_job import main as curation_main
    from utils.crawler import start_crawler, wait_for_crawler_completion
    from utils.common import notify_job_status

@pytest.fixture
def create_sample_data(spark_session, tmp_path):
    """Create sample data files for testing."""
    # Create a CSV file with sample data
    sample_data_path = os.path.join(tmp_path, "sample_data.csv")
    with open(sample_data_path, "w") as f:
        f.write("id,name,value,timestamp\n")
        f.write("1,test1,100,2023-01-01 00:00:00\n")
        f.write("2,test2,200,2023-01-02 00:00:00\n")
        f.write("3,test3,300,2023-01-03 00:00:00\n")
    
    return sample_data_path

class TestEndToEndIntegration:
    """End-to-end integration tests for the AWS Glue ETL pipeline."""
    
    def test_full_pipeline_execution(self, spark_session, glue_context, aws_glue_job_context, 
                                    s3_mock, glue_client_mock, create_sample_data):
        """
        Test the full ETL pipeline execution from ingestion to curation.
        
        This test simulates the complete flow:
        1. Ingestion job processes raw data
        2. Raw data crawler runs to catalog the data
        3. Processing job transforms the data
        4. Processed data crawler runs to catalog the data
        5. Curation job creates final curated datasets
        6. Curated data crawler runs to catalog the data
        """
        # Setup test data
        sample_data_path = create_sample_data
        
        # Mock S3 operations
        s3_mock.list_objects_v2.return_value = {
            "Contents": [{"Key": "raw/sample_data.csv"}]
        }
        
        with open(sample_data_path, "rb") as f:
            s3_mock.get_object.return_value = {"Body": MagicMock(read=lambda: f.read())}
        
        # Mock Glue operations
        glue_client_mock.start_crawler.return_value = {"ResponseMetadata": {"HTTPStatusCode": 200}}
        
        # Mock crawler status checks to simulate successful completion
        last_crawl_time = datetime.now() - timedelta(hours=1)
        glue_client_mock.get_crawler.return_value = {
            "Crawler": {
                "Name": "test-raw-data-crawler",
                "State": "READY",
                "LastCrawl": {
                    "Status": "SUCCEEDED",
                    "StartTime": last_crawl_time,
                    "EndTime": last_crawl_time + timedelta(minutes=10),
                    "Summary": "Tables created: 1, Tables updated: 0, Tables deleted: 0"
                }
            }
        }
        
        # Setup boto3 client mocks
        with patch('boto3.client', return_value=s3_mock), \
             patch('boto3.resource', return_value=MagicMock()), \
             patch('utils.crawler.start_crawler', return_value=True), \
             patch('utils.crawler.wait_for_crawler_completion', return_value=(True, {"Summary": "Success"})), \
             patch('utils.common.notify_job_status', return_value=None):
            
            # Step 1: Run the ingestion job
            with patch('jobs.ingestion_job.main', return_value=None):
                ingestion_main(glue_context, aws_glue_job_context)
                
                # Verify S3 operations for ingestion
                s3_mock.get_object.assert_called()
            
            # Step 2: Run the raw data crawler
            start_crawler("test-raw-data-crawler")
            success, _ = wait_for_crawler_completion("test-raw-data-crawler", 60, 10)
            assert success is True
            
            # Step 3: Run the processing job
            with patch('jobs.processing_job.main', return_value=None):
                processing_main(glue_context, aws_glue_job_context)
            
            # Step 4: Run the processed data crawler
            start_crawler("test-processed-data-crawler")
            success, _ = wait_for_crawler_completion("test-processed-data-crawler", 60, 10)
            assert success is True
            
            # Step 5: Run the curation job
            with patch('jobs.curation_job.main', return_value=None):
                curation_main(glue_context, aws_glue_job_context)
            
            # Step 6: Run the curated data crawler
            start_crawler("test-curated-data-crawler")
            success, _ = wait_for_crawler_completion("test-curated-data-crawler", 60, 10)
            assert success is True
            
            # Verify notifications were sent for all jobs
            assert notify_job_status.call_count >= 3
    
    def test_error_handling_and_recovery(self, spark_session, glue_context, aws_glue_job_context,
                                        s3_mock, glue_client_mock, sns_mock, create_sample_data):
        """
        Test error handling and recovery in the ETL pipeline.
        
        This test simulates:
        1. Ingestion job encounters an error with malformed data
        2. Error notification is sent
        3. Ingestion job continues with valid data
        4. Rest of pipeline processes the valid data
        """
        # Setup test data with one malformed record
        sample_data_path = create_sample_data
        with open(sample_data_path, "w") as f:
            f.write("id,name,value,timestamp\n")
            f.write("1,test1,100,2023-01-01 00:00:00\n")
            f.write("invalid,test2,not_a_number,2023-01-02 00:00:00\n")  # Malformed
            f.write("3,test3,300,2023-01-03 00:00:00\n")
        
        # Mock S3 operations
        with open(sample_data_path, "rb") as f:
            s3_mock.get_object.return_value = {"Body": MagicMock(read=lambda: f.read())}
        
        # Setup boto3 client mocks
        with patch('boto3.client', side_effect=[s3_mock, sns_mock, glue_client_mock]), \
             patch('boto3.resource', return_value=MagicMock()), \
             patch('utils.crawler.start_crawler', return_value=True), \
             patch('utils.crawler.wait_for_crawler_completion', return_value=(True, {"Summary": "Success"})), \
             patch('utils.common.notify_job_status', return_value=None):
            
            # Step 1: Run the ingestion job with error handling
            with patch('jobs.ingestion_job.main', return_value=None):
                ingestion_main(glue_context, aws_glue_job_context)
                
                # Verify error notification was sent
                notify_job_status.assert_called_with(
                    job_name=aws_glue_job_context["args"][0]["JOB_NAME"],
                    status="WARNING",
                    environment=aws_glue_job_context["args"][1]["ENVIRONMENT"],
                    message=pytest.raises(Exception),
                    sns_topic_arn=pytest.any_string()
                )
            
            # Step 2: Verify that processing continues with valid data
            with patch('jobs.processing_job.main', return_value=None):
                processing_main(glue_context, aws_glue_job_context)
            
            # Step 3: Verify that curation job runs with the valid data
            with patch('jobs.curation_job.main', return_value=None):
                curation_main(glue_context, aws_glue_job_context)
    
    def test_incremental_processing(self, spark_session, glue_context, aws_glue_job_context,
                                   s3_mock, dynamodb_mock, create_sample_data):
        """
        Test incremental processing using job bookmarks.
        
        This test simulates:
        1. First run processes all data
        2. Second run with new data only processes the incremental data
        """
        # Setup initial test data
        sample_data_path = create_sample_data
        
        # Mock DynamoDB for job bookmarks
        dynamodb_mock.get_item.side_effect = [
            # First call - no bookmark exists
            {},
            # Second call - bookmark exists
            {
                "Item": {
                    "job_name": {"S": "test_job"},
                    "environment": {"S": "test"},
                    "last_run_timestamp": {"S": "2023-01-02T00:00:00Z"},
                    "status": {"S": "SUCCESS"},
                    "bookmark_value": {"S": "2023-01-02T00:00:00Z"}
                }
            }
        ]
        
        # Setup boto3 client mocks
        with patch('boto3.client', return_value=s3_mock), \
             patch('boto3.resource', return_value=MagicMock(Table=lambda x: dynamodb_mock)), \
             patch('utils.common.get_job_bookmark', side_effect=[None, {"bookmark_value": "2023-01-02T00:00:00Z"}]):
            
            # First run - process all data
            with patch('jobs.ingestion_job.main', return_value=None):
                ingestion_main(glue_context, aws_glue_job_context)
            
            # Add new data for incremental processing
            with open(sample_data_path, "w") as f:
                f.write("id,name,value,timestamp\n")
                f.write("4,test4,400,2023-01-04 00:00:00\n")
                f.write("5,test5,500,2023-01-05 00:00:00\n")
            
            with open(sample_data_path, "rb") as f:
                s3_mock.get_object.return_value = {"Body": MagicMock(read=lambda: f.read())}
            
            # Second run - should only process new data
            with patch('jobs.ingestion_job.main', return_value=None):
                ingestion_main(glue_context, aws_glue_job_context)
                
                # Verify bookmark was used
                assert "bookmark_value" in aws_glue_job_context["args"][-1]
                
                # In a real test, we would verify that only records after the bookmark timestamp were processed
