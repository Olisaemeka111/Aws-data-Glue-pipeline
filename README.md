# Production-Grade AWS Glue ETL Pipeline

This repository contains Terraform code to provision a production-grade AWS Glue ETL pipeline architecture that processes large-scale data with high reliability, performance, and maintainability.

## 🏗️ Architecture Overview

The architecture implements a serverless ETL pipeline using AWS Glue with support for both batch and streaming data processing. It includes comprehensive guardrails for error handling, monitoring, security, and operational excellence.

### Key Components:
- **AWS Glue ETL Jobs** (Spark/Python) - Data processing and transformation
- **AWS Glue Workflows** - Job orchestration and dependency management
- **S3 Buckets** - Multi-layer data storage (raw, processed, curated, quality reports)
- **AWS Glue Data Catalog** - Metadata management and schema registry
- **CloudWatch** - Monitoring, alerting, and performance tracking
- **AWS Lambda** - Auxiliary processing and data connectors
- **SNS/SQS** - Notifications and queue management
- **AWS EventBridge** - Event-driven architecture and triggers
- **AWS DynamoDB** - Job bookmarking and state management

## 📊 Data Flow Process

### Process Flow Diagrams

The pipeline includes comprehensive process flow documentation:

1. **[Comprehensive Data Flow Diagram](docs/diagrams/comprehensive_data_flow_diagram.md)** - Complete end-to-end pipeline flow
2. **[Data Generation Flow Diagram](docs/diagrams/data_generation_flow.md)** - Data generation and ingestion process
3. **[Data Generation Process Documentation](docs/data_generation_process.md)** - Detailed data generation methods

### Data Processing Pipeline

```
Data Sources → Data Connectors → S3 Raw Bucket → Ingestion Job → 
Processed Bucket → Processing Job → Curated Bucket → Quality Job → 
Quality Reports → Data Access Layer (Athena, Redshift, QuickSight)
```

#### Data Generation Methods:
- **External Data Sources**: APIs, databases, files, streaming sources
- **Test Data Generation**: CI/CD test data, health check data, unit test data
- **Sample Data Creation**: Mock data for development and testing

#### Processing Layers:
1. **Data Ingestion Layer** - Multi-format reading, validation, metadata enrichment
2. **Data Processing Layer** - Business transformations, aggregations, enrichment
3. **Data Quality Layer** - Validation, scoring, anomaly detection
4. **Data Output Layer** - Curated data ready for consumption

## 🔧 ETL Jobs Architecture

### Job 1: Data Ingestion (`src/jobs/data_ingestion.py`)
- **Purpose**: Raw data intake and standardization
- **Input**: Raw S3 bucket (CSV, JSON, Parquet, ORC, Avro)
- **Output**: Processed S3 bucket (standardized Parquet)
- **Key Features**:
  - Multi-format file detection and reading
  - Schema standardization and column cleaning
  - Data quality validation (nulls, duplicates)
  - Metadata enrichment (timestamps, batch IDs)
  - Date partitioning (year/month/day)
  - Error handling and notifications

### Job 2: Data Processing (`src/jobs/data_processing.py`)
- **Purpose**: Business logic transformations
- **Input**: Processed S3 bucket
- **Output**: Curated S3 bucket
- **Key Features**:
  - Business rule applications
  - Data aggregations and calculations
  - Data enrichment from external sources
  - Advanced Spark SQL transformations
  - Schema evolution handling
  - Performance optimizations

### Job 3: Data Quality (`src/jobs/data_quality.py`)
- **Purpose**: Data validation and quality scoring
- **Input**: Curated S3 bucket
- **Output**: Quality reports and alerts
- **Key Features**:
  - Completeness checks (null value analysis)
  - Validity checks (data type compliance)
  - Consistency checks (referential integrity)
  - Accuracy checks (business rule compliance)
  - Anomaly detection
  - Quality score calculation (0-100)
  - Threshold-based alerting

## 📁 Repository Structure

```
├── README.md                           # This file
├── architecture/                       # Architecture diagrams and documentation
│   └── architecture_overview.md
├── terraform/                          # Terraform infrastructure code
│   ├── environments/                   # Environment-specific configurations
│   │   ├── dev/                       # Development environment
│   │   ├── staging/                   # Staging environment
│   │   └── prod/                      # Production environment
│   ├── modules/                       # Reusable Terraform modules
│   │   ├── glue/                      # AWS Glue resources
│   │   ├── monitoring/                # Monitoring resources
│   │   ├── networking/                # VPC and networking
│   │   ├── security/                  # IAM and security
│   │   └── storage/                   # S3 and storage resources
│   └── scripts/                       # Helper scripts
├── src/                                # Source code for Glue jobs
│   ├── jobs/                          # Glue job scripts
│   │   ├── data_ingestion.py          # Data ingestion job
│   │   ├── data_processing.py         # Data processing job
│   │   └── data_quality.py            # Data quality job
│   ├── lambda/                        # Lambda functions
│   │   ├── data_trigger/              # Data trigger Lambda
│   │   └── monitoring/                # Monitoring Lambda
│   ├── utils/                         # Utility functions
│   │   └── glue_utils.py              # Glue utilities
│   └── tests/                         # Test scripts
├── docs/                              # Additional documentation
│   ├── diagrams/                      # Process flow diagrams
│   │   ├── comprehensive_data_flow_diagram.md
│   │   ├── data_generation_flow.md
│   │   └── data_flow_diagram.md
│   ├── data_flow_processes.md         # Data flow documentation
│   └── data_generation_process.md     # Data generation documentation
├── scripts/                           # Deployment and utility scripts
│   ├── deploy.sh                      # Main deployment script
│   ├── convert_csv_to_excel.py        # Data conversion utilities
│   └── check_deployment_status.sh     # Deployment verification
└── ci-cd-glue-health-check-solution/  # CI/CD health check system
    ├── src/                           # Health check source code
    ├── scripts/                       # Health check scripts
    └── docs/                          # Health check documentation
```

## 🚀 Getting Started

### Prerequisites

1. **Install required tools**:
   - Terraform v1.0+
   - AWS CLI v2
   - Python 3.10+
   - Git

2. **Configure AWS credentials**:
   ```bash
   aws configure
   # Or use environment variables
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

### Quick Deployment

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd aws-data-glue-pipeline
   ```

2. **Deploy using the deployment script**:
   ```bash
   # Deploy to development environment
   ./scripts/deploy.sh dev
   
   # Deploy to production environment
   ./scripts/deploy.sh prod
   ```

3. **Manual Terraform deployment**:
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

### Data Pipeline Usage

1. **Upload data to the raw bucket**:
   ```bash
   # Upload sample data
   aws s3 cp sample-data.csv s3://glue-etl-pipeline-dev-raw/data/incoming/2024/01/15/
   ```

2. **Trigger the ETL workflow**:
   ```bash
   # Start the workflow manually
   aws glue start-workflow-run --name glue-etl-pipeline-dev-etl-workflow
   ```

3. **Monitor job execution**:
   ```bash
   # Check job status
   aws glue get-job-runs --job-name glue-etl-pipeline-dev-data-ingestion
   ```

## 📚 Documentation

### Process Flow Documentation
- **[Comprehensive Data Flow Diagram](docs/diagrams/comprehensive_data_flow_diagram.md)** - Complete end-to-end pipeline flow
- **[Data Generation Flow Diagram](docs/diagrams/data_generation_flow.md)** - Data generation and ingestion process
- **[Data Generation Process Documentation](docs/data_generation_process.md)** - Detailed data generation methods
- **[Data Flow Processes](docs/data_flow_processes.md)** - Detailed data flow documentation

### Architecture & Operations
- **[Architecture Overview](architecture/architecture_overview.md)** - System architecture design
- **[AWS Console Navigation Guide](AWS_Console_Navigation_Guide.md)** - AWS console navigation
- **[Pipeline Sequence Guide](AWS_Glue_Pipeline_Sequence_Guide.md)** - Step-by-step pipeline execution
- **[Pipeline Sequence Reference](AWS_Pipeline_Sequence_Reference.md)** - Detailed sequence reference

### Monitoring & Health Checks
- **[CI/CD Health Check Implementation](CI_CD_Glue_Health_Check_Implementation.md)** - Health check system
- **[Health Check Solution](ci-cd-glue-health-check-solution/)** - Complete health check solution

### Cost Management
- **[AWS Cost Analysis](aws%20costing/AWS_Cost_Analysis.md)** - Cost analysis and optimization
- **[Cost Summary Executive](aws%20costing/Cost_Summary_Executive.md)** - Executive cost summary
- **[EC2 Resources Cost Analysis](aws%20costing/EC2_Resources_Cost_Analysis.md)** - EC2 cost breakdown

## 🔧 Configuration

### Environment Variables
```bash
export ENVIRONMENT="dev"                    # Environment (dev/staging/prod)
export AWS_REGION="us-east-1"              # AWS region
export PROJECT_NAME="glue-etl-pipeline"    # Project name
export GLUE_VERSION="4.0"                  # Glue version
export PYTHON_VERSION="3.10"               # Python version
```

### Terraform Variables
Key variables can be configured in `terraform/environments/{env}/terraform.tfvars`:
```hcl
environment = "dev"
project_name = "glue-etl-pipeline"
glue_version = "4.0"
python_version = "3.10"
worker_type = "G.1X"
number_of_workers = 2
```

## 🧪 Testing

### Run Unit Tests
```bash
cd src/tests
python -m pytest test_glue_jobs.py -v
```

### Run Integration Tests
```bash
cd src/tests
python -m pytest test_end_to_end_integration.py -v
```

### Health Check Testing
```bash
cd ci-cd-glue-health-check-solution
./scripts/test_health_check_system.sh
```

## 📊 Monitoring

### CloudWatch Dashboards
- Job execution metrics
- Resource utilization
- Error rates and success rates
- Data processing volumes

### SNS Notifications
- Job success/failure alerts
- Data quality warnings
- Performance notifications
- System health alerts

### DynamoDB State Tracking
- Job execution status
- Processing metadata
- Error tracking
- Performance metrics

## 🔒 Security

- **Encryption**: KMS encryption for data at rest and in transit
- **VPC**: Private subnets for Glue jobs
- **IAM**: Least privilege access with role-based permissions
- **Security Scanning**: Automated security validation
- **Access Control**: Fine-grained S3 and Glue permissions

## 💰 Cost Optimization

- **S3 Lifecycle Policies**: Automated data archival
- **Glue Job Optimization**: Dynamic resource allocation
- **Data Partitioning**: Efficient query performance
- **Monitoring**: Cost alerts and budget management

## 🛠️ Troubleshooting

### Common Issues

1. **Job Failures**:
   ```bash
   # Check job logs
   aws logs describe-log-groups --log-group-name-prefix "/aws-glue/jobs"
   aws logs get-log-events --log-group-name "/aws-glue/jobs/glue-etl-pipeline-dev-data-ingestion" --log-stream-name "job-run-id"
   ```

2. **S3 Access Issues**:
   ```bash
   # Verify S3 bucket permissions
   aws s3 ls s3://glue-etl-pipeline-dev-raw/
   aws s3api get-bucket-policy --bucket glue-etl-pipeline-dev-raw
   ```

3. **Glue Job Timeout**:
   - Increase job timeout in Terraform configuration
   - Optimize Spark configuration for better performance
   - Check data volume and processing complexity

4. **Data Quality Issues**:
   - Review quality reports in S3 quality bucket
   - Check quality rules configuration
   - Validate input data format and schema

### Debug Commands

```bash
# Check deployment status
./scripts/check_deployment_status.sh

# Verify infrastructure
terraform plan -out=tfplan

# Test data pipeline
./ci-cd-glue-health-check-solution/scripts/test_health_check_system.sh

# Monitor job execution
aws glue get-job-runs --job-name glue-etl-pipeline-dev-data-ingestion --max-items 5
```

## 📈 Performance Optimization

### Glue Job Optimization
- Use appropriate worker types (G.1X, G.2X, G.025X)
- Configure Spark settings for your workload
- Enable adaptive query execution
- Use data partitioning for better performance

### S3 Optimization
- Use Parquet format with Snappy compression
- Implement data partitioning (year/month/day)
- Configure S3 lifecycle policies
- Use S3 Transfer Acceleration for large files

### Monitoring Best Practices
- Set up CloudWatch alarms for job failures
- Monitor data quality scores
- Track processing times and costs
- Implement automated alerting

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Check the documentation in the `docs/` directory
- Review the troubleshooting section above
- Create an issue in the repository
- Contact the development team

## 🔄 Version History

- **v1.0.0** - Initial release with basic ETL pipeline
- **v1.1.0** - Added data quality validation
- **v1.2.0** - Implemented health check system
- **v1.3.0** - Enhanced monitoring and alerting
- **v1.4.0** - Added comprehensive documentation and process flow diagrams
