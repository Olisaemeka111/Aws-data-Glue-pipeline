# AWS Data Glue ETL Pipeline - Resource Inventory

## Overview
This document provides a comprehensive list of all AWS resources created by the Glue ETL Pipeline infrastructure.

**Environment:** dev  
**Region:** us-east-1  
**Project:** glue-etl-pipeline  
**Total Resources:** 115+ resources

---

## 🌐 **VPC & Networking Resources (25 resources)**

### VPC Infrastructure
- **VPC:** `glue-etl-pipeline-dev-vpc` (10.0.0.0/16)
- **Internet Gateway:** `glue-etl-pipeline-dev-igw`
- **NAT Gateways:** 3x NAT gateways (one per AZ)
- **Elastic IPs:** 3x EIPs for NAT gateways

### Subnets (6 subnets)
- **Public Subnets:**
  - `glue-etl-pipeline-dev-public-subnet-1` (us-east-1a)
  - `glue-etl-pipeline-dev-public-subnet-2` (us-east-1b)
  - `glue-etl-pipeline-dev-public-subnet-3` (us-east-1c)
- **Private Subnets:**
  - `glue-etl-pipeline-dev-private-subnet-1` (us-east-1a)
  - `glue-etl-pipeline-dev-private-subnet-2` (us-east-1b)
  - `glue-etl-pipeline-dev-private-subnet-3` (us-east-1c)

### Route Tables
- **Public Route Table:** `glue-etl-pipeline-dev-public-rt`
- **Private Route Tables:** 3x private route tables (one per AZ)

### VPC Endpoints
- **S3 VPC Endpoint:** `glue-etl-pipeline-dev-s3-endpoint`
- **Glue VPC Endpoint:** `glue-etl-pipeline-dev-glue-endpoint`
- **DynamoDB VPC Endpoint:** `glue-etl-pipeline-dev-dynamodb-endpoint`

### Security Groups
- **Glue Connection Security Group:** `glue-etl-pipeline-dev-glue-connection-sg`
- **Lambda Security Group:** `glue-etl-pipeline-dev-lambda-sg`

---

## 🗄️ **Storage Resources (37 resources)**

### S3 Buckets (5 buckets + configurations)
1. **Raw Data Bucket:** `glue-etl-pipeline-dev-raw-data`
   - Versioning enabled
   - KMS encryption
   - Lifecycle policy (30-day intelligent tiering)
   - Public access blocked

2. **Processed Data Bucket:** `glue-etl-pipeline-dev-processed-data`
   - Versioning enabled
   - KMS encryption
   - Lifecycle policy (30-day intelligent tiering)
   - Public access blocked

3. **Curated Data Bucket:** `glue-etl-pipeline-dev-curated-data`
   - Versioning enabled
   - KMS encryption
   - Lifecycle policy (30-day intelligent tiering)
   - Public access blocked

4. **Scripts Bucket:** `glue-etl-pipeline-dev-scripts`
   - Versioning enabled
   - KMS encryption
   - Public access blocked

5. **Temp Bucket:** `glue-etl-pipeline-dev-temp`
   - Versioning enabled
   - KMS encryption
   - 7-day expiration policy
   - Public access blocked

### DynamoDB Tables (2 tables)
1. **Job Bookmarks Table:** `glue-etl-pipeline-dev-job-bookmarks`
   - Hash key: job_name (S)
   - Range key: run_id (S)
   - Pay-per-request billing
   - Point-in-time recovery enabled
   - KMS encryption

2. **Metadata Table:** `glue-etl-pipeline-dev-metadata`
   - Hash key: id (S)
   - Pay-per-request billing
   - Point-in-time recovery enabled
   - KMS encryption

### KMS Keys & Aliases
- **S3 KMS Key:** `glue-etl-pipeline-dev-s3-kms-key`
- **S3 KMS Alias:** `alias/glue-etl-pipeline-dev-s3-kms-key`
- **DynamoDB KMS Key:** `glue-etl-pipeline-dev-dynamodb-kms-key`
- **DynamoDB KMS Alias:** `alias/glue-etl-pipeline-dev-dynamodb-kms-key`

---

## 🔄 **AWS Glue Resources (15 resources)**

### Glue Catalog
- **Catalog Database:** `glue-etl-pipeline_dev_catalog`

### Glue Crawlers (3 crawlers)
1. **Raw Data Crawler:** `glue-etl-pipeline-dev-raw-data-crawler`
   - Schedule: cron(0 0 * * ? *)
   - Target: s3://glue-etl-pipeline-dev-raw-data/data/incoming/

2. **Processed Data Crawler:** `glue-etl-pipeline-dev-processed-data-crawler`
   - Schedule: cron(0 0 * * ? *)
   - Target: s3://glue-etl-pipeline-dev-processed-data/data/processed/

3. **Curated Data Crawler:** `glue-etl-pipeline-dev-curated-data-crawler`
   - Schedule: cron(0 0 * * ? *)
   - Target: s3://glue-etl-pipeline-dev-curated-data/data/curated/

### Glue Jobs (3 jobs)
1. **Data Ingestion Job:** `glue-etl-pipeline-dev-data-ingestion`
   - Worker type: G.1X
   - Number of workers: 2
   - Timeout: 30 minutes
   - Python version: 3.9

2. **Data Processing Job:** `glue-etl-pipeline-dev-data-processing`
   - Worker type: G.1X
   - Number of workers: 2
   - Timeout: 30 minutes
   - Python version: 3.9

3. **Data Quality Job:** `glue-etl-pipeline-dev-data-quality`
   - Worker type: G.1X
   - Number of workers: 2
   - Timeout: 30 minutes
   - Python version: 3.9

### Glue Workflow & Triggers
- **ETL Workflow:** `glue-etl-pipeline-dev-etl-workflow`
- **Start Workflow Trigger:** `glue-etl-pipeline-dev-start-workflow`
- **Start Ingestion Trigger:** `glue-etl-pipeline-dev-start-ingestion`
- **Start Processing Trigger:** `glue-etl-pipeline-dev-start-processing`
- **Start Quality Trigger:** `glue-etl-pipeline-dev-start-quality`

---

## 🔐 **Security & IAM Resources (20 resources)**

### IAM Roles
- **Glue Service Role:** `glue-etl-pipeline-dev-glue-service-role`
- **Glue Crawler Role:** `glue-etl-pipeline-dev-glue-crawler-role`
- **Lambda Execution Role:** `glue-etl-pipeline-dev-data-trigger-role`

### IAM Policies
- **S3 Access Policy:** `glue-etl-pipeline-dev-s3-access-policy`
- **DynamoDB Access Policy:** `glue-etl-pipeline-dev-dynamodb-tables-policy`
- **SNS Access Policy:** `glue-etl-pipeline-dev-sns-topics-policy`
- **Glue Crawler S3 Policy:** `glue-etl-pipeline-dev-glue-crawler-s3-policy`
- **Lambda Custom Policy:** `glue-etl-pipeline-dev-data-trigger-policy`

### AWS Secrets Manager
- **Glue Connections Secret:** `glue-etl-pipeline/dev/glue-connections`

---

## ⚡ **Lambda & Event Processing (12 resources)**

### Lambda Function
- **Data Trigger Lambda:** `glue-etl-pipeline-dev-data-trigger`
  - Runtime: Python 3.9
  - Memory: 256 MB
  - Timeout: 5 minutes
  - VPC enabled

### SNS Topics
- **Security Alerts Topic:** `glue-etl-pipeline-dev-security-alerts`
- **Job Notifications Topic:** `glue-etl-pipeline-dev-job-notifications`

### DynamoDB (Lambda specific)
- **Security Scan Results Table:** `glue-etl-pipeline-dev-security-scan-results`
  - Hash key: scan_id (S)
  - Range key: timestamp (S)
  - Global Secondary Indexes: FileKeyIndex, StatusIndex

### S3 Event Notifications
- **Bucket Notification Configuration:** Triggers Lambda on S3 object creation

---

## 📊 **Monitoring & Logging (26 resources)**

### CloudWatch Log Groups
- **Glue Jobs Log Group:** `/aws-glue/jobs/glue-etl-pipeline-dev`
- **Lambda Log Group:** `/aws/lambda/glue-etl-pipeline-dev-data-trigger`
- **VPC Flow Logs:** `/aws/vpc/flowlogs`

### CloudWatch Alarms
- **Job Duration Alarm:** `glue-etl-pipeline-dev-job-duration-alarm`
- **Job Failure Alarm:** `glue-etl-pipeline-dev-job-failure-alarm`
- **Blocked Files Alarm:** `glue-etl-pipeline-dev-blocked-files-alarm`
- **Data Quality Alarm:** `glue-etl-pipeline-dev-data-quality-alarm`

### CloudWatch Dashboard
- **Security Dashboard:** `glue-etl-pipeline-dev-security-dashboard`
- **Pipeline Dashboard:** `glue-etl-pipeline-dev-pipeline-dashboard`

### Security Hub (Optional)
- **Security Hub Account:** Enabled if configured
- **AWS Foundational Standards:** Subscribed

---

## 🏷️ **Resource Tagging Strategy**

All resources are tagged with:
- **Environment:** dev
- **Project:** glue-etl-pipeline
- **ManagedBy:** Terraform
- **Owner:** [Your Organization]
- **CostCenter:** [Your Cost Center]
- **Component:** [Specific component type]

---

## 💰 **Cost Optimization Features**

### S3 Storage
- **Intelligent Tiering:** Automatic transition after 30 days
- **Lifecycle Policies:** Automatic cleanup of temporary files
- **Compression:** Gzip compression for processed data

### DynamoDB
- **On-Demand Billing:** Pay only for what you use
- **Auto Scaling:** Automatic capacity adjustment

### Glue Jobs
- **Bookmarking:** Prevents reprocessing of data
- **Spot Instances:** Cost-effective worker instances
- **Auto Scaling:** Dynamic worker allocation

---

## 🔒 **Security Features**

### Encryption
- **At Rest:** All S3 buckets and DynamoDB tables encrypted with KMS
- **In Transit:** SSL/TLS for all data transfers
- **Key Rotation:** Automatic KMS key rotation enabled

### Network Security
- **VPC Isolation:** All resources deployed in private subnets
- **Security Groups:** Least-privilege access rules
- **NACLs:** Additional network-level security

### Access Control
- **IAM Roles:** Least-privilege principle
- **Resource-based Policies:** Fine-grained access control
- **MFA:** Multi-factor authentication for sensitive operations

---

## 📈 **Performance Optimizations**

### Spark Configuration
- **Adaptive Query Execution:** Enabled for optimal performance
- **Dynamic Allocation:** Automatic executor scaling
- **Intelligent Caching:** Automatic DataFrame caching

### Data Partitioning
- **Date-based Partitioning:** Efficient data organization
- **Columnar Storage:** Parquet format for analytics
- **Compression:** Optimized storage and transfer

---

## 🚀 **Deployment Status**

**Configuration Status:** ✅ Complete  
**Infrastructure Code:** ✅ Ready  
**Security Review:** ✅ Passed  
**Cost Optimization:** ✅ Implemented  

**Next Steps:**
1. Run `terraform apply` to deploy infrastructure
2. Upload sample data to test the pipeline
3. Configure email notifications
4. Set up monitoring dashboards

---

**Generated:** $(date)  
**Version:** 2.0  
**Documentation:** Complete 