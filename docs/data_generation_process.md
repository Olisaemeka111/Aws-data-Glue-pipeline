# Data Generation Process Documentation

This document details how data is generated and ingested into the AWS Glue ETL pipeline.

## Data Generation Methods

### 1. External Data Sources

#### API Data Sources
- **REST APIs**: Real-time data from external services
- **GraphQL APIs**: Flexible data querying and retrieval
- **Database APIs**: Direct database connections via Lambda functions
- **Third-party APIs**: Integration with external data providers

#### File-based Sources
- **CSV Files**: Comma-separated values with headers
- **JSON Files**: Structured data in JSON format
- **Parquet Files**: Columnar storage format for analytics
- **ORC Files**: Optimized Row Columnar format
- **Avro Files**: Schema-based binary data format

#### Streaming Sources
- **Kinesis Data Streams**: Real-time data streaming
- **Kafka**: Message streaming platform
- **SQS**: Simple Queue Service for message processing

### 2. Sample Data Generation

#### CI/CD Test Data Generation
The pipeline automatically generates test data during CI/CD processes:

```bash
# Location: .github/workflows/ci-cd.yml
# Generate test data for integration testing
mkdir -p test-data
echo "id,customer_id,transaction_date,amount" > test-data/test.csv
echo "1,C001,2023-01-01,100.00" >> test-data/test.csv
echo "2,C002,2023-01-01,200.00" >> test-data/test.csv
echo "3,C003,2023-01-01,300.00" >> test-data/test.csv

# Upload to S3 for processing
BUCKET_NAME="glue-etl-pipeline-${ENVIRONMENT}-raw"
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
aws s3 cp test-data/test.csv s3://$BUCKET_NAME/data/incoming/$YEAR/$MONTH/$DAY/test.csv
```

#### Health Check Data Generation
For pipeline health monitoring, stub data is generated:

```python
# Location: ci-cd-glue-health-check-solution/src/jobs/health_check/data_processing_health_check.py
def create_stub_data():
    if is_health_check_mode():
        logger.info("🧪 Creating stub data...")
        test_data = [("test_1", "value_1", datetime.now())]
        schema = StructType([
            StructField("id", StringType(), True),
            StructField("value", StringType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        df = spark.createDataFrame(test_data, schema)
        return DynamicFrame.fromDF(df, glueContext, "stub_data")
    else:
        return glueContext.create_dynamic_frame.from_catalog(
            database="your_database", table_name="your_table"
        )
```

#### Unit Test Data Generation
For testing individual components:

```python
# Location: tests/test_glue_jobs.py
# Sample test data for unit testing
data = [
    {"id": "1", "customer_id": "C001", "transaction_date": "2023-01-01", "amount": "100.00"},
    {"id": "2", "customer_id": "C002", "transaction_date": "2023-01-01", "amount": "200.00"},
    {"id": "3", "customer_id": "C003", "transaction_date": "2023-01-01", "amount": "300.00"},
    {"id": "4", "customer_id": "C004", "transaction_date": "2023-01-01", "amount": "400.00"},
    {"id": "5", "customer_id": "C005", "transaction_date": "2023-01-01", "amount": "500.00"},
]
test_df = spark.createDataFrame(data)
```

### 3. Data Generation Scripts

#### Sample Data Creation Script
```python
# Location: src/tests/conftest.py
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
```

## Data Ingestion Process

### 1. Data Arrival
Data arrives in the S3 ingestion bucket at:
```
s3://glue-etl-pipeline-{environment}-raw/data/incoming/YYYY/MM/DD/
```

### 2. File Format Detection
The ingestion job automatically detects file formats:

```python
# Location: src/jobs/data_ingestion.py
def detect_file_format(s3_client, bucket: str, key: str) -> str:
    """Detect file format based on extension and content."""
    file_extension = key.split('.')[-1].lower()
    
    if file_extension in ['csv']:
        return 'csv'
    elif file_extension in ['json']:
        return 'json'
    elif file_extension in ['parquet']:
        return 'parquet'
    elif file_extension in ['orc']:
        return 'orc'
    elif file_extension in ['avro']:
        return 'avro'
    else:
        # Try to detect from content
        return 'csv'  # Default fallback
```

### 3. Data Processing Pipeline

#### Step 1: File Reading
```python
# Multi-format file reading
connection_options = {
    "paths": [f"s3://{raw_bucket}/{file_key}"]
}

format_options = {}
if file_format == 'csv':
    format_options = {
        "withHeader": True,
        "separator": ",",
        "optimizePerformance": True,
        "multiline": False
    }
elif file_format == 'json':
    format_options = {
        "multiline": True
    }

dynamic_frame = glueContext.create_dynamic_frame.from_options(
    connection_type="s3",
    connection_options=connection_options,
    format=file_format,
    format_options=format_options
)
```

#### Step 2: Data Validation
```python
# Data quality validation
quality_metrics = validate_data_quality(df, file_key)
processing_summary['quality_metrics'][file_key] = quality_metrics
```

#### Step 3: Metadata Enrichment
```python
# Add processing metadata
df = df.withColumn("source_file", F.lit(file_key))
df = df.withColumn("ingestion_timestamp", F.current_timestamp())
df = df.withColumn("batch_id", F.lit(str(uuid.uuid4())))
df = df.withColumn("file_format", F.lit(file_format))
df = df.withColumn("environment", F.lit(environment))
```

#### Step 4: Date Partitioning
```python
# Add date partitioning columns
df = df.withColumn("year", F.lit(year))
df = df.withColumn("month", F.lit(month))
df = df.withColumn("day", F.lit(day))
```

#### Step 5: Output Writing
```python
# Write to processed bucket in Parquet format
sink = glueContext.write_dynamic_frame.from_options(
    frame=dynamic_frame_output,
    connection_type="s3",
    connection_options={
        "path": full_target_path,
        "partitionKeys": ["year", "month", "day"],
        "compression": "snappy"
    },
    format="parquet",
    format_options={
        "useThreads": True,
        "blockSize": 134217728,  # 128MB
        "pageSize": 1048576      # 1MB
    },
    transformation_ctx="processed_data_sink"
)
```

## Data Quality Validation

### Quality Rules
The pipeline includes comprehensive data quality validation:

```python
# Location: src/jobs/data_quality.py
def perform_data_quality_checks(df, quality_rules):
    """Perform comprehensive data quality checks."""
    quality_results = {
        'completeness': check_completeness(df, quality_rules),
        'validity': check_validity(df, quality_rules),
        'consistency': check_consistency(df, quality_rules),
        'accuracy': check_accuracy(df, quality_rules),
        'timeliness': check_timeliness(df, quality_rules)
    }
    return quality_results
```

### Quality Metrics
- **Completeness**: Null value analysis and missing data detection
- **Validity**: Data type compliance and format validation
- **Consistency**: Referential integrity and cross-field validation
- **Accuracy**: Business rule compliance and data accuracy
- **Timeliness**: Data freshness and processing time validation

## Monitoring and Alerting

### Job State Tracking
```python
# Location: src/jobs/data_ingestion.py
def update_job_state(dynamodb_client, table_name: str, job_name: str, status: str, 
                    message: Optional[str] = None, metadata: Optional[Dict[str, Any]] = None):
    """Update job state in DynamoDB with proper error handling."""
    item = {
        'job_name': {'S': job_name},
        'status': {'S': status},
        'updated_at': {'S': datetime.datetime.now().isoformat()},
        'environment': {'S': os.environ.get('ENVIRONMENT', 'unknown')}
    }
    # ... additional metadata handling
```

### Notification System
```python
# SNS notifications for job status
def send_notification(sns_client, topic_arn: str, subject: str, message: str):
    """Send SNS notification with error handling."""
    sns_client.publish(
        TopicArn=topic_arn,
        Subject=subject[:100],
        Message=message[:262144]
    )
```

## Data Flow Summary

1. **Data Sources** → External APIs, databases, files, streams
2. **Data Generation** → Test data, sample data, health check data
3. **Data Ingestion** → S3 bucket with format detection and validation
4. **Data Processing** → ETL jobs with business transformations
5. **Data Quality** → Validation, scoring, and reporting
6. **Data Output** → Curated data ready for consumption
7. **Data Access** → Athena, Redshift, QuickSight, APIs
8. **Monitoring** → CloudWatch, SNS, DynamoDB state tracking

This comprehensive data generation and processing pipeline ensures reliable, high-quality data flow from various sources through to business-ready outputs.
