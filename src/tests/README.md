# AWS Glue ETL Pipeline Tests

This directory contains automated tests for the AWS Glue ETL pipeline, including unit tests, integration tests, and end-to-end tests.

## Test Structure

- `conftest.py` - Contains pytest fixtures used across test modules
- `test_ingestion_job.py` - Tests for the data ingestion Glue job
- `test_processing_job.py` - Tests for the data processing Glue job
- `test_curation_job.py` - Tests for the data curation Glue job
- `test_utils.py` - Tests for utility functions used across Glue jobs
- `test_crawler_integration.py` - Tests for Glue Data Crawler integration
- `test_end_to_end_integration.py` - End-to-end integration tests for the full pipeline

## Running Tests

### Prerequisites

Install the required dependencies:

```bash
pip install -r requirements.txt
```

### Running All Tests

```bash
pytest
```

### Running Specific Test Files

```bash
pytest test_ingestion_job.py
```

### Running Tests with Coverage

```bash
pytest --cov=src
```

## Test Environment

The tests use:

- Local PySpark session for testing Glue job functionality
- Mocked AWS services (S3, DynamoDB, Glue, etc.) using unittest.mock
- Sample data files for testing data processing logic

## Adding New Tests

When adding new tests:

1. Create test files following the naming convention `test_*.py`
2. Use the existing fixtures in `conftest.py`
3. Mock external AWS services to avoid actual AWS calls
4. Add appropriate assertions to verify expected behavior

## CI/CD Integration

These tests are designed to be run as part of the CI/CD pipeline to ensure code quality before deployment.
