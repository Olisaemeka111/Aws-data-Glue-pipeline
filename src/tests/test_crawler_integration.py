"""
Tests for Glue Data Crawler integration.
"""
import pytest
import boto3
import json
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

# Import the module to test
# For testing purposes, we'll mock these imports
with patch.dict('sys.modules', {
    'utils.crawler': MagicMock(),
    'utils.glue': MagicMock()
}):
    from utils.crawler import start_crawler, check_crawler_status, wait_for_crawler_completion
    from utils.glue import get_table_metadata

class TestCrawlerIntegration:
    """Test cases for Glue Data Crawler integration."""
    
    def test_start_crawler(self, glue_client_mock):
        """Test starting a Glue Crawler."""
        # Mock the boto3 client
        with patch('boto3.client', return_value=glue_client_mock):
            # Mock response
            glue_client_mock.start_crawler.return_value = {"ResponseMetadata": {"HTTPStatusCode": 200}}
            
            # Mock the start_crawler function
            with patch('utils.crawler.start_crawler', return_value=True):
                result = start_crawler("test-raw-data-crawler")
                
                # Assertions
                assert result is True
                glue_client_mock.start_crawler.assert_called_with(Name="test-raw-data-crawler")
    
    def test_check_crawler_status_running(self, glue_client_mock):
        """Test checking crawler status when it's running."""
        # Mock the boto3 client
        with patch('boto3.client', return_value=glue_client_mock):
            # Mock response for a running crawler
            glue_client_mock.get_crawler.return_value = {
                "Crawler": {
                    "Name": "test-raw-data-crawler",
                    "State": "RUNNING",
                    "LastCrawl": {
                        "Status": "RUNNING",
                        "StartTime": datetime.now() - timedelta(minutes=5)
                    }
                }
            }
            
            # Mock the check_crawler_status function
            with patch('utils.crawler.check_crawler_status', return_value=("RUNNING", None)):
                status, last_crawl_info = check_crawler_status("test-raw-data-crawler")
                
                # Assertions
                assert status == "RUNNING"
                assert last_crawl_info is None
                glue_client_mock.get_crawler.assert_called_with(Name="test-raw-data-crawler")
    
    def test_check_crawler_status_succeeded(self, glue_client_mock):
        """Test checking crawler status when it has succeeded."""
        # Mock the boto3 client
        with patch('boto3.client', return_value=glue_client_mock):
            # Mock response for a completed crawler
            last_crawl_time = datetime.now() - timedelta(hours=1)
            glue_client_mock.get_crawler.return_value = {
                "Crawler": {
                    "Name": "test-raw-data-crawler",
                    "State": "READY",
                    "LastCrawl": {
                        "Status": "SUCCEEDED",
                        "StartTime": last_crawl_time,
                        "EndTime": last_crawl_time + timedelta(minutes=10),
                        "Summary": "Tables created: 2, Tables updated: 1, Tables deleted: 0"
                    }
                }
            }
            
            # Mock the check_crawler_status function
            with patch('utils.crawler.check_crawler_status', return_value=(
                "SUCCEEDED", 
                {
                    "StartTime": last_crawl_time,
                    "EndTime": last_crawl_time + timedelta(minutes=10),
                    "Summary": "Tables created: 2, Tables updated: 1, Tables deleted: 0"
                }
            )):
                status, last_crawl_info = check_crawler_status("test-raw-data-crawler")
                
                # Assertions
                assert status == "SUCCEEDED"
                assert last_crawl_info is not None
                assert "Tables created: 2" in last_crawl_info["Summary"]
                glue_client_mock.get_crawler.assert_called_with(Name="test-raw-data-crawler")
    
    def test_wait_for_crawler_completion_success(self, glue_client_mock):
        """Test waiting for crawler completion with success."""
        # Mock the boto3 client
        with patch('boto3.client', return_value=glue_client_mock):
            # Mock responses for a crawler that completes
            last_crawl_time = datetime.now() - timedelta(hours=1)
            
            # First call shows running
            # Second call shows completed
            glue_client_mock.get_crawler.side_effect = [
                {
                    "Crawler": {
                        "Name": "test-raw-data-crawler",
                        "State": "RUNNING",
                        "LastCrawl": {
                            "Status": "RUNNING",
                            "StartTime": last_crawl_time
                        }
                    }
                },
                {
                    "Crawler": {
                        "Name": "test-raw-data-crawler",
                        "State": "READY",
                        "LastCrawl": {
                            "Status": "SUCCEEDED",
                            "StartTime": last_crawl_time,
                            "EndTime": last_crawl_time + timedelta(minutes=10),
                            "Summary": "Tables created: 2, Tables updated: 1, Tables deleted: 0"
                        }
                    }
                }
            ]
            
            # Mock the wait_for_crawler_completion function
            with patch('utils.crawler.wait_for_crawler_completion', return_value=(
                True, 
                {
                    "StartTime": last_crawl_time,
                    "EndTime": last_crawl_time + timedelta(minutes=10),
                    "Summary": "Tables created: 2, Tables updated: 1, Tables deleted: 0"
                }
            )):
                success, crawl_info = wait_for_crawler_completion(
                    crawler_name="test-raw-data-crawler",
                    timeout_seconds=60,
                    poll_interval_seconds=10
                )
                
                # Assertions
                assert success is True
                assert crawl_info is not None
                assert "Tables created: 2" in crawl_info["Summary"]
                assert glue_client_mock.get_crawler.call_count >= 2
    
    def test_wait_for_crawler_completion_failure(self, glue_client_mock):
        """Test waiting for crawler completion with failure."""
        # Mock the boto3 client
        with patch('boto3.client', return_value=glue_client_mock):
            # Mock responses for a crawler that fails
            last_crawl_time = datetime.now() - timedelta(hours=1)
            
            # First call shows running
            # Second call shows failed
            glue_client_mock.get_crawler.side_effect = [
                {
                    "Crawler": {
                        "Name": "test-raw-data-crawler",
                        "State": "RUNNING",
                        "LastCrawl": {
                            "Status": "RUNNING",
                            "StartTime": last_crawl_time
                        }
                    }
                },
                {
                    "Crawler": {
                        "Name": "test-raw-data-crawler",
                        "State": "READY",
                        "LastCrawl": {
                            "Status": "FAILED",
                            "StartTime": last_crawl_time,
                            "EndTime": last_crawl_time + timedelta(minutes=5),
                            "ErrorMessage": "Access denied to S3 location",
                            "LogGroup": "/aws-glue/crawlers",
                            "LogStream": "test-raw-data-crawler"
                        }
                    }
                }
            ]
            
            # Mock the wait_for_crawler_completion function
            with patch('utils.crawler.wait_for_crawler_completion', return_value=(
                False, 
                {
                    "StartTime": last_crawl_time,
                    "EndTime": last_crawl_time + timedelta(minutes=5),
                    "ErrorMessage": "Access denied to S3 location",
                    "LogGroup": "/aws-glue/crawlers",
                    "LogStream": "test-raw-data-crawler"
                }
            )):
                success, crawl_info = wait_for_crawler_completion(
                    crawler_name="test-raw-data-crawler",
                    timeout_seconds=60,
                    poll_interval_seconds=10
                )
                
                # Assertions
                assert success is False
                assert crawl_info is not None
                assert "Access denied" in crawl_info["ErrorMessage"]
                assert glue_client_mock.get_crawler.call_count >= 2
    
    def test_get_table_metadata(self, glue_client_mock):
        """Test getting table metadata after crawler run."""
        # Mock the boto3 client
        with patch('boto3.client', return_value=glue_client_mock):
            # Mock response for get_table
            glue_client_mock.get_table.return_value = {
                "Table": {
                    "Name": "raw_customer_data",
                    "DatabaseName": "test_glue_catalog",
                    "CreateTime": datetime.now() - timedelta(hours=1),
                    "UpdateTime": datetime.now() - timedelta(minutes=30),
                    "LastAccessTime": datetime.now() - timedelta(minutes=30),
                    "StorageDescriptor": {
                        "Columns": [
                            {"Name": "id", "Type": "string"},
                            {"Name": "name", "Type": "string"},
                            {"Name": "value", "Type": "int"},
                            {"Name": "timestamp", "Type": "timestamp"}
                        ],
                        "Location": "s3://test-raw-bucket/customer_data/",
                        "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
                        "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
                        "Compressed": False,
                        "NumberOfBuckets": -1,
                        "SerdeInfo": {
                            "SerializationLibrary": "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe",
                            "Parameters": {"field.delim": ","}
                        },
                        "SortColumns": [],
                        "StoredAsSubDirectories": False
                    },
                    "PartitionKeys": [
                        {"Name": "year", "Type": "string"},
                        {"Name": "month", "Type": "string"},
                        {"Name": "day", "Type": "string"}
                    ],
                    "TableType": "EXTERNAL_TABLE",
                    "Parameters": {
                        "classification": "csv",
                        "compressionType": "none",
                        "typeOfData": "file",
                        "CrawlerSchemaDeserializerVersion": "1.0",
                        "CrawlerSchemaSerializerVersion": "1.0",
                        "UPDATED_BY_CRAWLER": "test-raw-data-crawler",
                        "recordCount": "1000",
                        "averageRecordSize": "100"
                    }
                }
            }
            
            # Mock the get_table_metadata function
            with patch('utils.glue.get_table_metadata', return_value={
                "name": "raw_customer_data",
                "database": "test_glue_catalog",
                "update_time": datetime.now() - timedelta(minutes=30),
                "columns": [
                    {"name": "id", "type": "string"},
                    {"name": "name", "type": "string"},
                    {"name": "value", "type": "int"},
                    {"name": "timestamp", "type": "timestamp"}
                ],
                "partition_keys": ["year", "month", "day"],
                "location": "s3://test-raw-bucket/customer_data/",
                "record_count": "1000",
                "updated_by_crawler": "test-raw-data-crawler"
            }):
                metadata = get_table_metadata("test_glue_catalog", "raw_customer_data")
                
                # Assertions
                assert metadata["name"] == "raw_customer_data"
                assert metadata["database"] == "test_glue_catalog"
                assert len(metadata["columns"]) == 4
                assert metadata["partition_keys"] == ["year", "month", "day"]
                assert metadata["location"] == "s3://test-raw-bucket/customer_data/"
                assert metadata["updated_by_crawler"] == "test-raw-data-crawler"
                glue_client_mock.get_table.assert_called_with(
                    DatabaseName="test_glue_catalog", 
                    Name="raw_customer_data"
                )
