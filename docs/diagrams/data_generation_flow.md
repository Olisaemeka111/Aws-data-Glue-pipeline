# Data Generation Flow Diagram

This diagram specifically focuses on the data generation and ingestion process in the AWS Glue ETL pipeline.

```mermaid
graph TD
    %% Data Generation Sources
    subgraph "Data Generation Sources"
        API["External APIs<br/>• REST APIs<br/>• GraphQL APIs<br/>• Third-party APIs"]
        DB["Database Sources<br/>• RDS/Aurora<br/>• External DBs<br/>• Data warehouses"]
        Files["File Sources<br/>• CSV files<br/>• JSON files<br/>• Parquet files<br/>• ORC/Avro files"]
        Streams["Streaming Sources<br/>• Kinesis Data Streams<br/>• Kafka<br/>• SQS queues"]
    end

    %% Test Data Generation
    subgraph "Test Data Generation"
        CICD["CI/CD Test Data<br/>• Automated test data<br/>• Integration testing<br/>• Pipeline validation"]
        Health["Health Check Data<br/>• Stub data creation<br/>• Pipeline monitoring<br/>• Automated testing"]
        Unit["Unit Test Data<br/>• Mock data<br/>• Component testing<br/>• Development testing"]
    end

    %% Data Connectors
    subgraph "Data Connectors"
        Lambda1["Data Trigger Lambda<br/>• File validation<br/>• Security scanning<br/>• Event processing<br/>• Format detection"]
        Lambda2["Database Connector<br/>• DB connections<br/>• Query execution<br/>• Data extraction<br/>• Format conversion"]
        Lambda3["API Connector<br/>• API calls<br/>• Authentication<br/>• Rate limiting<br/>• Error handling"]
        Kinesis["Kinesis Consumer<br/>• Stream processing<br/>• Real-time ingestion<br/>• Data buffering"]
    end

    %% Data Ingestion
    subgraph "Data Ingestion Layer"
        S3Raw["S3 Raw Bucket<br/>s3://glue-etl-pipeline-{env}-raw<br/>• data/incoming/YYYY/MM/DD/<br/>• Multiple formats supported<br/>• Immutable storage"]
        
        Validation["Data Validation<br/>• File size checks<br/>• Format validation<br/>• Security scanning<br/>• Naming conventions"]
        
        FormatDetection["Format Detection<br/>• Extension-based<br/>• Content analysis<br/>• Auto-detection<br/>• Fallback handling"]
    end

    %% Data Processing
    subgraph "Data Processing Pipeline"
        IngestionJob["Data Ingestion Job<br/>src/jobs/data_ingestion.py<br/>• Multi-format reading<br/>• Schema standardization<br/>• Metadata enrichment<br/>• Quality validation"]
        
        ProcessingJob["Data Processing Job<br/>src/jobs/data_processing.py<br/>• Business transformations<br/>• Data aggregations<br/>• Data enrichment<br/>• Performance optimization"]
        
        QualityJob["Data Quality Job<br/>src/jobs/data_quality.py<br/>• Quality rule validation<br/>• Anomaly detection<br/>• Quality scoring<br/>• Trend analysis"]
    end

    %% Data Storage
    subgraph "Data Storage Layers"
        S3Processed["S3 Processed Bucket<br/>• Cleaned & validated data<br/>• Standardized Parquet<br/>• Snappy compression<br/>• Date partitioning"]
        
        S3Curated["S3 Curated Bucket<br/>• Business-ready data<br/>• Aggregated datasets<br/>• Query-optimized<br/>• Final output layer"]
        
        S3Quality["S3 Quality Reports<br/>• Quality metrics<br/>• Data profiles<br/>• Anomaly reports<br/>• Trend analysis"]
    end

    %% Data Flow Connections
    API --> Lambda3
    DB --> Lambda2
    Files --> Lambda1
    Streams --> Kinesis
    
    CICD --> S3Raw
    Health --> S3Raw
    Unit --> S3Raw
    
    Lambda1 --> S3Raw
    Lambda2 --> S3Raw
    Lambda3 --> S3Raw
    Kinesis --> S3Raw
    
    S3Raw --> Validation
    Validation --> FormatDetection
    FormatDetection --> IngestionJob
    
    IngestionJob --> S3Processed
    S3Processed --> ProcessingJob
    ProcessingJob --> S3Curated
    S3Curated --> QualityJob
    QualityJob --> S3Quality

    %% Styling
    classDef source fill:#e3f2fd,stroke:#0277bd,stroke-width:2px
    classDef test fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef connector fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef storage fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef process fill:#fce4ec,stroke:#c2185b,stroke-width:2px

    class API,DB,Files,Streams source
    class CICD,Health,Unit test
    class Lambda1,Lambda2,Lambda3,Kinesis,Validation,FormatDetection connector
    class S3Raw,S3Processed,S3Curated,S3Quality storage
    class IngestionJob,ProcessingJob,QualityJob process
```

## Data Generation Process Details

### 1. External Data Sources

#### API Data Sources
- **REST APIs**: Real-time data from external services
- **GraphQL APIs**: Flexible data querying and retrieval
- **Third-party APIs**: Integration with external data providers

#### Database Sources
- **RDS/Aurora**: Relational database connections
- **External Databases**: Cross-platform database integration
- **Data Warehouses**: Enterprise data warehouse connections

#### File Sources
- **CSV Files**: Comma-separated values with headers
- **JSON Files**: Structured data in JSON format
- **Parquet Files**: Columnar storage format for analytics
- **ORC/Avro Files**: Optimized binary data formats

#### Streaming Sources
- **Kinesis Data Streams**: Real-time data streaming
- **Kafka**: Message streaming platform
- **SQS**: Simple Queue Service for message processing

### 2. Test Data Generation

#### CI/CD Test Data
```bash
# Automated test data generation
echo "id,customer_id,transaction_date,amount" > test-data/test.csv
echo "1,C001,2023-01-01,100.00" >> test-data/test.csv
echo "2,C002,2023-01-01,200.00" >> test-data/test.csv
```

#### Health Check Data
```python
# Stub data for pipeline health monitoring
def create_stub_data():
    test_data = [("test_1", "value_1", datetime.now())]
    schema = StructType([
        StructField("id", StringType(), True),
        StructField("value", StringType(), True),
        StructField("timestamp", TimestampType(), True)
    ])
    return spark.createDataFrame(test_data, schema)
```

#### Unit Test Data
```python
# Mock data for component testing
data = [
    {"id": "1", "customer_id": "C001", "amount": "100.00"},
    {"id": "2", "customer_id": "C002", "amount": "200.00"},
    {"id": "3", "customer_id": "C003", "amount": "300.00"},
]
```

### 3. Data Connectors

#### Data Trigger Lambda
- File validation and security scanning
- Event processing and format detection
- S3 event handling and routing

#### Database Connector
- Database connection management
- Query execution and data extraction
- Format conversion and optimization

#### API Connector
- API authentication and rate limiting
- Error handling and retry logic
- Data transformation and formatting

#### Kinesis Consumer
- Real-time stream processing
- Data buffering and batching
- Error handling and recovery

### 4. Data Processing Pipeline

#### Ingestion Job
- Multi-format file reading (CSV, JSON, Parquet, ORC, Avro)
- Schema standardization and column cleaning
- Data quality validation and metadata enrichment
- Date partitioning and Parquet output with Snappy compression

#### Processing Job
- Business rule applications and data transformations
- Data aggregations and calculations
- Data enrichment from external sources
- Spark optimizations and performance tuning

#### Quality Job
- Configurable quality rules validation
- Data profiling and anomaly detection
- Quality score calculation and trend analysis
- Threshold-based alerting and reporting

### 5. Data Storage Layers

#### Raw Data Layer
- Original data preservation in S3
- Immutable storage with versioning
- Multiple format support
- Lifecycle policies for cost optimization

#### Processed Data Layer
- Cleaned and validated data
- Standardized Parquet format
- Snappy compression for efficiency
- Date partitioning for query performance

#### Curated Data Layer
- Business-ready datasets
- Aggregated and enriched data
- Query-optimized structures
- Final output for consumption

#### Quality Reports Layer
- Quality metrics and data profiles
- Anomaly reports and trend analysis
- Monitoring and alerting data
- Historical quality tracking

This comprehensive data generation and processing flow ensures reliable, high-quality data pipeline from various sources through to business-ready outputs.
