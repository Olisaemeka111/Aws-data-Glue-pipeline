# Comprehensive AWS Glue ETL Pipeline Data Flow Diagram

This diagram shows the complete data flow from data generation through ingestion, transformation, and output layers.

```mermaid
graph TD
    %% Data Generation Layer
    subgraph "Data Generation & Sources"
        DS1["External Data Sources\n• APIs\n• Databases\n• Files\n• Streams"]
        DS2["Sample Data Generation\n• Test Data Creation\n• Mock Data\n• Health Check Data"]
        DS3["CI/CD Test Data\n• Automated Test Data\n• Integration Test Data"]
    end

    %% Data Ingestion Layer
    subgraph "Data Ingestion Layer"
        S3IN["S3 Ingestion Bucket\ns3://glue-etl-pipeline-{env}-raw\n• data/incoming/YYYY/MM/DD/\n• Multiple formats: CSV, JSON, Parquet"]
        Lambda1["Data Trigger Lambda\n• File validation\n• Security scanning\n• Event processing"]
        Lambda2["Data Connector Lambda\n• Database connections\n• API integrations\n• Data format conversion"]
    end

    %% Data Processing Orchestration
    subgraph "Processing Orchestration"
        EventBridge["CloudWatch EventBridge\n• S3 Event triggers\n• Scheduled triggers\n• Manual triggers"]
        GlueWorkflow["Glue Workflow\n• Job orchestration\n• Dependency management\n• Error handling"]
        Schedule["Scheduled Trigger\n• Cron expressions\n• Time-based execution"]
        Manual["Manual Trigger\n• AWS Console\n• API calls\n• CI/CD pipeline"]
    end

    %% Data Processing Jobs
    subgraph "ETL Processing Jobs"
        RawCrawler["Raw Data Crawler\n• Schema discovery\n• Metadata extraction\n• Catalog updates"]
        
        IngestionJob["Data Ingestion Job\nsrc/jobs/data_ingestion.py\n• Multi-format reading\n• Schema standardization\n• Data quality validation\n• Metadata enrichment\n• Partitioning (year/month/day)"]
        
        ProcessCrawler["Processed Data Crawler\n• Schema evolution tracking\n• Metadata updates"]
        
        ProcessingJob["Data Processing Job\nsrc/jobs/data_processing.py\n• Business transformations\n• Data aggregations\n• Data enrichment\n• Spark optimizations\n• Incremental processing"]
        
        QualityJob["Data Quality Job\nsrc/jobs/data_quality.py\n• Quality rule validation\n• Anomaly detection\n• Quality scoring\n• Trend analysis"]
        
        CurateCrawler["Curated Data Crawler\n• Final schema validation\n• Query optimization metadata"]
    end

    %% Data Storage Layers
    subgraph "Data Storage Layers"
        S3Raw["S3 Raw Bucket\ns3://glue-etl-pipeline-{env}-raw\n• Original data preservation\n• Immutable storage\n• Versioning enabled"]
        
        S3Process["S3 Processed Bucket\ns3://glue-etl-pipeline-{env}-processed\n• Cleaned & validated data\n• Standardized Parquet format\n• Snappy compression\n• Partitioned by date"]
        
        S3Curate["S3 Curated Bucket\ns3://glue-etl-pipeline-{env}-curated\n• Business-ready datasets\n• Aggregated data\n• Query-optimized structure"]
        
        S3Quality["S3 Quality Reports\ns3://glue-etl-pipeline-{env}-quality\n• Quality reports\n• Data profiles\n• Anomaly reports"]
    end

    %% Data Catalog & Metadata
    subgraph "Data Catalog & Metadata"
        GlueCatalog["Glue Data Catalog\n• Schema registry\n• Metadata management\n• Table definitions\n• Partition information"]
        DynamoDB["Job State Tracking\n• Job execution status\n• Processing metadata\n• Error tracking\n• Performance metrics"]
    end

    %% Data Access & Query Layer
    subgraph "Data Access & Query Layer"
        Athena["Amazon Athena\n• SQL-based queries\n• Ad-hoc analytics\n• Data exploration"]
        Redshift["Redshift Spectrum\n• Data warehouse integration\n• Complex analytics\n• Business intelligence"]
        S3Access["S3 Direct Access\n• Programmatic access\n• API integrations\n• Data exports"]
        QuickSight["Amazon QuickSight\n• Data visualization\n• Dashboards\n• Business reports"]
    end

    %% Monitoring & Alerting
    subgraph "Monitoring & Alerting"
        CloudWatch["CloudWatch Metrics\n• Job performance\n• Resource utilization\n• Error tracking"]
        MonitoringLambda["Monitoring Lambda\n• Health checks\n• Alert processing\n• Status reporting"]
        SNS["SNS Notifications\n• Success/failure alerts\n• Quality warnings\n• Performance notifications"]
        HealthCheck["Health Check System\n• Pipeline validation\n• Data quality monitoring\n• Automated testing"]
    end

    %% Data Flow Connections
    DS1 --> Lambda1
    DS1 --> Lambda2
    DS2 --> S3IN
    DS3 --> S3IN
    
    Lambda1 --> S3IN
    Lambda2 --> S3IN
    
    S3IN --> |S3 Event| EventBridge
    Schedule --> EventBridge
    Manual --> EventBridge
    
    EventBridge --> GlueWorkflow
    
    %% Processing Flow
    GlueWorkflow --> |Trigger| RawCrawler
    S3IN --> |Read| IngestionJob
    RawCrawler --> GlueCatalog
    IngestionJob --> |Write| S3Raw
    
    GlueWorkflow --> |Trigger| IngestionJob
    S3Raw --> |Read| ProcessCrawler
    ProcessCrawler --> GlueCatalog
    
    GlueWorkflow --> |Trigger| ProcessingJob
    S3Raw --> |Read| ProcessingJob
    ProcessingJob --> |Write| S3Process
    
    GlueWorkflow --> |Trigger| QualityJob
    S3Process --> |Read| QualityJob
    QualityJob --> |Write| S3Curate
    QualityJob --> |Write| S3Quality
    
    S3Process --> |Read| CurateCrawler
    CurateCrawler --> GlueCatalog
    
    %% Data Access Flow
    GlueCatalog --> Athena
    GlueCatalog --> Redshift
    S3Curate --> |Direct Access| S3Access
    S3Curate --> QuickSight
    
    %% Monitoring Flow
    IngestionJob --> CloudWatch
    ProcessingJob --> CloudWatch
    QualityJob --> CloudWatch
    CloudWatch --> MonitoringLambda
    MonitoringLambda --> SNS
    
    %% State Tracking
    IngestionJob --> |Job State| DynamoDB
    ProcessingJob --> |Job State| DynamoDB
    QualityJob --> |Job State| DynamoDB
    MonitoringLambda --> |Read State| DynamoDB
    
    %% Health Check Flow
    HealthCheck --> |Test Data| S3IN
    HealthCheck --> |Validation| GlueWorkflow
    HealthCheck --> |Monitoring| CloudWatch

    %% Styling
    classDef source fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef storage fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef process fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef catalog fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef monitoring fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef access fill:#e0f2f1,stroke:#004d40,stroke-width:2px

    class DS1,DS2,DS3 source
    class S3IN,S3Raw,S3Process,S3Curate,S3Quality storage
    class IngestionJob,ProcessingJob,QualityJob,RawCrawler,ProcessCrawler,CurateCrawler,GlueWorkflow process
    class GlueCatalog,DynamoDB catalog
    class CloudWatch,MonitoringLambda,SNS,HealthCheck monitoring
    class Athena,Redshift,S3Access,QuickSight access
```

## Data Generation Process

### 1. External Data Sources
- **APIs**: REST/GraphQL endpoints providing real-time data
- **Databases**: RDS, Aurora, or external database connections
- **Files**: CSV, JSON, Parquet files from various sources
- **Streams**: Kinesis Data Streams for real-time data ingestion

### 2. Sample Data Generation
The pipeline includes several methods for generating test and sample data:

#### Test Data Creation (CI/CD)
```bash
# Automated test data generation in CI/CD pipeline
echo "id,customer_id,transaction_date,amount" > test-data/test.csv
echo "1,C001,2023-01-01,100.00" >> test-data/test.csv
echo "2,C002,2023-01-01,200.00" >> test-data/test.csv
```

#### Health Check Data
```python
# Stub data creation for health checks
def create_stub_data():
    test_data = [("test_1", "value_1", datetime.now())]
    schema = StructType([
        StructField("id", StringType(), True),
        StructField("value", StringType(), True),
        StructField("timestamp", TimestampType(), True)
    ])
    df = spark.createDataFrame(test_data, schema)
    return DynamicFrame.fromDF(df, glueContext, "stub_data")
```

#### Mock Data for Testing
```python
# Sample test data in test files
data = [
    {"id": "1", "customer_id": "C001", "transaction_date": "2023-01-01", "amount": "100.00"},
    {"id": "2", "customer_id": "C002", "transaction_date": "2023-01-01", "amount": "200.00"},
    {"id": "3", "customer_id": "C003", "transaction_date": "2023-01-01", "amount": "300.00"},
]
```

## Data Processing Flow Details

### Phase 1: Data Ingestion
1. **Data Arrival**: Files uploaded to `s3://glue-etl-pipeline-{env}-raw/data/incoming/YYYY/MM/DD/`
2. **Format Detection**: Automatic detection of CSV, JSON, Parquet, ORC, Avro formats
3. **Validation**: File size, type, naming convention, and security checks
4. **Processing**: Multi-format reading, schema standardization, metadata enrichment
5. **Output**: Standardized Parquet files with Snappy compression and date partitioning

### Phase 2: Data Processing
1. **Business Transformations**: Data deduplication, business rule applications
2. **Data Enrichment**: Lookups, joins, aggregations, calculations
3. **Spark Optimizations**: Adaptive query execution, dynamic partition pruning
4. **Output**: Business-ready datasets in curated bucket

### Phase 3: Data Quality
1. **Quality Validation**: Completeness, validity, consistency, accuracy checks
2. **Anomaly Detection**: Statistical analysis and trend monitoring
3. **Quality Scoring**: 0-100 quality score calculation
4. **Reporting**: Quality reports and alerts based on thresholds

## Data Output & Consumption

### Storage Layers
- **Raw Layer**: Original data preservation with versioning
- **Processed Layer**: Cleaned, validated, and standardized data
- **Curated Layer**: Business-ready, aggregated, and enriched data
- **Quality Layer**: Quality reports, data profiles, and monitoring data

### Access Methods
- **Athena**: SQL-based ad-hoc queries and analytics
- **Redshift Spectrum**: Data warehouse integration and complex analytics
- **S3 Direct Access**: Programmatic access and API integrations
- **QuickSight**: Data visualization and business intelligence dashboards

### Monitoring & Alerting
- **CloudWatch**: Performance metrics, resource utilization, error tracking
- **SNS**: Success/failure notifications, quality warnings
- **Health Checks**: Automated pipeline validation and testing
- **DynamoDB**: Job state tracking and processing metadata
