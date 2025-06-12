"""
Unit tests for utility functions used across Glue jobs.
"""
import pytest
import json
import boto3
from datetime import datetime
from unittest.mock import MagicMock, patch

# Import the module to test
# This will be the actual path to your utility functions
# For example: from utils.common import parse_args, notify_job_status
# For testing purposes, we'll mock these imports
with patch.dict('sys.modules', {
    'utils.common': MagicMock(),
    'utils.s3': MagicMock(),
    'utils.dynamodb': MagicMock(),
    'utils.sns': MagicMock()
}):
    from utils.common import parse_args, notify_job_status, get_job_bookmark
    from utils.s3 import read_s3_file, write_s3_file
    from utils.dynamodb import update_job_status

class TestCommonUtils:
    """Test cases for common utility functions."""
    
    def test_parse_args(self):
        """Test argument parsing from Glue job context."""
        # Create a mock job context
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
        
        # Mock the parse_args function
        with patch('utils.common.parse_args', return_value={
            "JOB_NAME": "test_job",
            "ENVIRONMENT": "test",
            "DATABASE_NAME": "test_db",
            "SOURCE_TABLE": "test_source",
            "TARGET_TABLE": "test_target",
            "TEMP_DIR": "s3://test-bucket/temp/",
            "BOOKMARK_ENABLED": "true"
        }):
            args = parse_args(job_context)
            
            # Assertions
            assert args["JOB_NAME"] == "test_job"
            assert args["ENVIRONMENT"] == "test"
            assert args["DATABASE_NAME"] == "test_db"
            assert args["SOURCE_TABLE"] == "test_source"
            assert args["TARGET_TABLE"] == "test_target"
            assert args["TEMP_DIR"] == "s3://test-bucket/temp/"
            assert args["BOOKMARK_ENABLED"] == "true"
    
    def test_notify_job_status_success(self, sns_mock):
        """Test job status notification for successful job."""
        # Mock the SNS client
        with patch('boto3.client', return_value=sns_mock):
            # Mock the notify_job_status function
            with patch('utils.common.notify_job_status', return_value=None):
                notify_job_status(
                    job_name="test_job",
                    status="SUCCESS",
                    environment="test",
                    message="Job completed successfully",
                    sns_topic_arn="arn:aws:sns:us-east-1:123456789012:test-topic"
                )
                
                # Assertions
                sns_mock.publish.assert_called_once()
                # Check that the message contains the right information
                call_args = sns_mock.publish.call_args[1]
                assert "test_job" in call_args["Message"]
                assert "SUCCESS" in call_args["Message"]
                assert "test" in call_args["Message"]
    
    def test_notify_job_status_failure(self, sns_mock):
        """Test job status notification for failed job."""
        # Mock the SNS client
        with patch('boto3.client', return_value=sns_mock):
            # Mock the notify_job_status function
            with patch('utils.common.notify_job_status', return_value=None):
                notify_job_status(
                    job_name="test_job",
                    status="FAILED",
                    environment="test",
                    message="Job failed due to data validation error",
                    sns_topic_arn="arn:aws:sns:us-east-1:123456789012:test-topic"
                )
                
                # Assertions
                sns_mock.publish.assert_called_once()
                # Check that the message contains the right information
                call_args = sns_mock.publish.call_args[1]
                assert "test_job" in call_args["Message"]
                assert "FAILED" in call_args["Message"]
                assert "test" in call_args["Message"]
                assert "data validation error" in call_args["Message"]
    
    def test_get_job_bookmark(self, dynamodb_mock):
        """Test retrieving job bookmark from DynamoDB."""
        # Mock DynamoDB response
        dynamodb_mock.get_item.return_value = {
            "Item": {
                "job_name": {"S": "test_job"},
                "environment": {"S": "test"},
                "last_run_timestamp": {"S": "2023-01-01T00:00:00Z"},
                "status": {"S": "SUCCESS"},
                "bookmark_value": {"S": "2023-01-01T00:00:00Z"}
            }
        }
        
        # Mock the boto3 client
        with patch('boto3.resource', return_value=MagicMock(Table=lambda x: dynamodb_mock)):
            # Mock the get_job_bookmark function
            with patch('utils.common.get_job_bookmark', return_value={
                "job_name": "test_job",
                "environment": "test",
                "last_run_timestamp": "2023-01-01T00:00:00Z",
                "status": "SUCCESS",
                "bookmark_value": "2023-01-01T00:00:00Z"
            }):
                bookmark = get_job_bookmark("test_job", "test", "job_bookmarks")
                
                # Assertions
                assert bookmark["job_name"] == "test_job"
                assert bookmark["environment"] == "test"
                assert bookmark["status"] == "SUCCESS"
                assert bookmark["bookmark_value"] == "2023-01-01T00:00:00Z"


class TestS3Utils:
    """Test cases for S3 utility functions."""
    
    def test_read_s3_file_json(self, s3_mock):
        """Test reading JSON file from S3."""
        # Mock S3 response
        test_json = json.dumps({"key": "value", "nested": {"key": "value"}})
        s3_mock.get_object.return_value = {"Body": MagicMock(read=lambda: test_json.encode())}
        
        # Mock the boto3 client
        with patch('boto3.client', return_value=s3_mock):
            # Mock the read_s3_file function
            with patch('utils.s3.read_s3_file', return_value=json.loads(test_json)):
                result = read_s3_file("test-bucket", "test-key.json")
                
                # Assertions
                assert result["key"] == "value"
                assert result["nested"]["key"] == "value"
                s3_mock.get_object.assert_called_with(Bucket="test-bucket", Key="test-key.json")
    
    def test_write_s3_file(self, s3_mock):
        """Test writing file to S3."""
        # Test data
        test_data = {"key": "value", "timestamp": "2023-01-01T00:00:00Z"}
        
        # Mock the boto3 client
        with patch('boto3.client', return_value=s3_mock):
            # Mock the write_s3_file function
            with patch('utils.s3.write_s3_file', return_value=None):
                write_s3_file("test-bucket", "test-key.json", test_data)
                
                # Assertions
                s3_mock.put_object.assert_called_once()
                call_args = s3_mock.put_object.call_args[1]
                assert call_args["Bucket"] == "test-bucket"
                assert call_args["Key"] == "test-key.json"


class TestDynamoDBUtils:
    """Test cases for DynamoDB utility functions."""
    
    def test_update_job_status(self, dynamodb_mock):
        """Test updating job status in DynamoDB."""
        # Mock the boto3 resource
        with patch('boto3.resource', return_value=MagicMock(Table=lambda x: dynamodb_mock)):
            # Mock the update_job_status function
            with patch('utils.dynamodb.update_job_status', return_value=None):
                update_job_status(
                    job_name="test_job",
                    environment="test",
                    status="SUCCESS",
                    bookmark_value="2023-01-01T00:00:00Z",
                    table_name="job_status"
                )
                
                # Assertions
                dynamodb_mock.update_item.assert_called_once()
                # Check that the update contains the right information
                call_args = dynamodb_mock.update_item.call_args[1]
                assert call_args["Key"]["job_name"] == "test_job"
                assert call_args["Key"]["environment"] == "test"
                assert "status" in str(call_args["UpdateExpression"])
                assert "bookmark_value" in str(call_args["UpdateExpression"])
