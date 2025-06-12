# AWS Glue ETL Pipeline Operations Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Environment Setup](#environment-setup)
4. [Deployment](#deployment)
5. [Monitoring and Alerting](#monitoring-and-alerting)
6. [Troubleshooting](#troubleshooting)
7. [Disaster Recovery](#disaster-recovery)
8. [Security Best Practices](#security-best-practices)
9. [Cost Optimization](#cost-optimization)
10. [Maintenance](#maintenance)

## Introduction

This operations guide provides detailed instructions for deploying, operating, and maintaining the AWS Glue ETL pipeline. The pipeline is designed to process large-scale data (≥1TB daily) reliably and efficiently using AWS Glue 4.0 (Spark 3.3, Python 3.10).

## Architecture Overview

The AWS Glue ETL pipeline consists of the following components:

- **Storage**: S3 buckets for raw, processed, curated, scripts, and temporary data
- **Processing**: AWS Glue jobs for data ingestion, processing, and quality validation
- **Orchestration**: AWS Glue workflows and triggers for job sequencing
- **State Management**: DynamoDB tables for job bookmarking and state tracking
- **Networking**: VPC with private/public subnets and VPC endpoints for AWS services
- **Security**: IAM roles with least privilege, KMS encryption, security groups
- **Monitoring**: CloudWatch logs, metrics, alarms, dashboards, and SNS notifications

The data flows through the pipeline in the following stages:
1. **Ingestion**: Raw data is ingested from source systems into the raw S3 bucket
2. **Processing**: Data is transformed and stored in the processed S3 bucket
3. **Quality Validation**: Data quality checks are performed
4. **Curation**: Validated data is stored in the curated S3 bucket for consumption

## Environment Setup

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Terraform v1.5.0 or later
- Python 3.10 or later

### AWS Account Setup

1. Create an IAM user with appropriate permissions for Terraform deployment
2. Configure AWS CLI with the IAM user credentials:
   ```bash
   aws configure
   ```

### Local Development Environment

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd AWS\ Data\ Glue\ pipeline
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Deployment

### Initial Deployment

1. Review and customize the Terraform variables in `terraform/environments/<env>/variables.tf`

2. Use the deployment script:
   ```bash
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh --environment dev --region us-east-1 --action apply
   ```

3. Alternatively, deploy manually with Terraform:
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan -var="aws_region=us-east-1"
   terraform apply -var="aws_region=us-east-1"
   ```

### Updating the Pipeline

1. Make changes to the Terraform code or Glue job scripts

2. Deploy the changes:
   ```bash
   ./scripts/deploy.sh --environment dev --region us-east-1 --action apply
   ```

### CI/CD Pipeline

The project includes a GitHub Actions workflow for CI/CD:

1. **Validate**: Checks Terraform format and validates modules
2. **Plan**: Generates and uploads Terraform plan
3. **Deploy**: Applies Terraform changes and uploads Glue job scripts
4. **Test**: Runs tests against the deployed infrastructure
5. **Cleanup**: Removes test data

To trigger a deployment:
1. Push changes to the `main` or `develop` branch
2. Or manually trigger the workflow from GitHub Actions UI

## Monitoring and Alerting

### CloudWatch Dashboards

Access the CloudWatch dashboard for monitoring the ETL pipeline:
1. Open the AWS Management Console
2. Navigate to CloudWatch > Dashboards
3. Select the dashboard named `glue-etl-pipeline-<env>-glue-dashboard`

The dashboard includes:
- Job success/failure metrics
- Job duration
- Memory usage
- Data processed (read/write bytes)

### Alerts and Notifications

The following alerts are configured:
- **Job Failure**: Triggers when a job fails
- **Long Duration**: Triggers when a job runs longer than expected
- **High Memory Usage**: Triggers when memory usage exceeds 85%

Alerts are sent to the SNS topic `glue-etl-pipeline-<env>-alerts` and delivered to subscribed email addresses.

### Enhanced Monitoring

The Lambda function `glue-etl-pipeline-<env>-monitoring` provides enhanced monitoring:
- Detailed job run reports
- Performance metrics analysis
- Daily summary reports

## Troubleshooting

### Common Issues

#### Job Failures

1. Check the CloudWatch logs:
   ```bash
   aws logs get-log-events --log-group-name "/aws-glue/glue-etl-pipeline-<env>" --log-stream-name "<job-name>"
   ```

2. Check the job state in DynamoDB:
   ```bash
   aws dynamodb get-item --table-name "glue-etl-pipeline-<env>-job-state" --key '{"job_name":{"S":"<job-name>"}}'
   ```

#### Performance Issues

1. Check the CloudWatch metrics for memory usage and duration
2. Consider increasing the number of workers or worker type
3. Review the Spark UI logs for detailed performance information

### Debugging Glue Jobs

1. Enable job bookmarks for incremental processing:
   ```python
   job.init(job_name, args, {'--job-bookmark-option': 'job-bookmark-enable'})
   ```

2. Add additional logging:
   ```python
   logger.info(f"Processing data: {data_frame.count()} records")
   ```

3. Use Glue development endpoints for interactive debugging

## Disaster Recovery

### Backup Strategy

- **S3 Buckets**: Versioning is enabled for all buckets
- **DynamoDB Tables**: Point-in-time recovery is enabled
- **Cross-Region Replication**: Enabled for production environment

### Recovery Procedures

#### S3 Data Recovery

1. Identify the version to restore:
   ```bash
   aws s3api list-object-versions --bucket "glue-etl-pipeline-<env>-raw" --prefix "data/"
   ```

2. Restore the version:
   ```bash
   aws s3api restore-object --bucket "glue-etl-pipeline-<env>-raw" --key "data/file.csv" --version-id "<version-id>"
   ```

#### DynamoDB Recovery

1. Restore the table to a point in time:
   ```bash
   aws dynamodb restore-table-to-point-in-time \
     --source-table-name "glue-etl-pipeline-<env>-job-state" \
     --target-table-name "glue-etl-pipeline-<env>-job-state-restored" \
     --use-latest-restorable-time
   ```

#### Cross-Region Failover

For production environment with cross-region replication:

1. Update DNS records to point to the secondary region
2. Promote the replicated resources to primary

## Security Best Practices

### Data Protection

- **Encryption at Rest**: All S3 buckets and DynamoDB tables are encrypted with KMS
- **Encryption in Transit**: All communications use TLS
- **Access Control**: IAM roles follow the principle of least privilege

### Network Security

- **VPC Isolation**: Glue jobs run in private subnets
- **VPC Endpoints**: Used for secure access to AWS services
- **Security Groups**: Restrict traffic to necessary ports and protocols

### Secrets Management

- Sensitive information is stored in AWS Secrets Manager
- Access to secrets is restricted by IAM policies

### Compliance

- AWS Config rules monitor encryption compliance
- CloudTrail logs all API calls for audit purposes

## Cost Optimization

### Glue Job Optimization

- Use appropriate worker type (G.1X for memory-intensive, G.2X for compute-intensive)
- Adjust number of workers based on data volume
- Set appropriate timeouts to avoid running unnecessarily long

### Storage Optimization

- S3 lifecycle policies move older data to lower-cost storage tiers
- Enable compression for Parquet files

### Monitoring Costs

1. Use AWS Cost Explorer to track costs by service and tag
2. Set up AWS Budgets to alert on cost thresholds

## Maintenance

### Regular Maintenance Tasks

1. **Schema Evolution**: Update Glue crawlers when source schemas change
2. **Dependency Updates**: Update Glue version and Python libraries
3. **Security Patches**: Apply security updates to all components

### Version Control

- All infrastructure code is version controlled in Git
- All changes should go through code review and CI/CD pipeline

### Documentation

- Keep this operations guide updated
- Document all changes in release notes
- Maintain architecture diagrams

### Testing

- Run unit tests for Glue job scripts:
  ```bash
  python -m unittest discover -s tests
  ```

- Run integration tests in the development environment before promoting to production
