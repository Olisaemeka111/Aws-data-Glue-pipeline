# Security Scanning Integration

This document describes the security scanning features integrated into the AWS Glue ETL pipeline, which are triggered when new data is injected into the data source.

## Overview

The security scanning integration provides automated security checks for all incoming data before it enters the ETL pipeline. This helps prevent processing of potentially malicious or non-compliant data, protecting the pipeline and downstream systems.

## Architecture

![Security Scanning Architecture](diagrams/security_scanning_architecture.svg)

The security scanning process follows these steps:

1. **Data Injection**: New data is uploaded to the source S3 bucket.
2. **Lambda Trigger**: An S3 event notification triggers the `data_trigger` Lambda function.
3. **Security Scanning**: The Lambda function performs security checks on the incoming data:
   - File size validation
   - File type validation
   - Malware scanning (simulated)
   - Sensitive data detection
   - File integrity check
4. **Results Storage**: Scan results are stored in DynamoDB for auditing and reporting.
5. **Security Notifications**: Security alerts are sent via SNS for any issues detected.
6. **Security Hub Integration**: Security findings are reported to AWS Security Hub.
7. **Pipeline Triggering**: If the data passes security checks, the Glue workflow is triggered.

## Security Checks

### File Size Validation
- Ensures files don't exceed the configured maximum size (default: 100MB).
- Prevents denial-of-service attacks through oversized files.

### File Type Validation
- Restricts processing to allowed file types (default: csv, json, parquet, avro).
- Prevents execution of potentially malicious file types.

### Malware Scanning
- Checks files for potential malware signatures.
- In production, this would integrate with a dedicated malware scanning service.

### Sensitive Data Detection
- Identifies common sensitive data patterns like credit card numbers, SSNs, API keys, etc.
- Helps enforce data governance and compliance requirements.

### File Integrity Check
- Verifies that files can be properly read and processed.
- Prevents pipeline failures due to corrupted files.

## Security Alerting and Monitoring

### Real-time Alerts
- SNS notifications are sent when security issues are detected.
- Alerts include details about the file, issue type, and severity.

### Security Dashboard
- CloudWatch dashboard displays security metrics:
  - Blocked files count
  - Security scan results by category
  - Trend analysis of security issues

### Security Hub Integration
- Security findings are reported to AWS Security Hub.
- Enables centralized security monitoring and compliance reporting.

## DynamoDB Audit Trail

All security scan results are stored in a DynamoDB table with the following information:
- Scan ID
- File key and bucket
- Timestamp
- Scan status (CLEAN, WARNING, BLOCKED, ERROR)
- Severity level
- Detailed list of issues detected

## Configuration Options

The security scanning can be configured through Terraform variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `max_file_size_mb` | Maximum allowed file size in MB | 100 |
| `allowed_file_types` | List of allowed file extensions | ["csv", "json", "parquet", "avro"] |
| `blocked_files_threshold` | Threshold for blocked files alarm | 5 |
| `enable_security_hub` | Whether to enable Security Hub integration | true |

## Implementation Details

### Lambda Function
The security scanning is implemented in the `data_trigger` Lambda function, which is triggered by S3 events when new data is uploaded.

### Terraform Resources
The security scanning infrastructure is defined in the `lambda_trigger` Terraform module, which creates:
- Lambda function
- IAM roles and policies
- S3 event notifications
- DynamoDB table for scan results
- SNS topic for security alerts
- CloudWatch alarms and dashboard
- Security Hub integration

## Best Practices

1. **Regular Updates**: Keep the security scanning patterns and rules updated.
2. **Monitoring**: Review the security dashboard regularly.
3. **Alerting**: Ensure the right team members receive security alerts.
4. **Testing**: Periodically test the security scanning with known test cases.
5. **Integration**: Consider integrating with additional security services for enhanced protection.

## Deployment

The security scanning infrastructure is deployed as part of the main Terraform deployment:

```bash
# Package the Lambda function
./scripts/package_lambda.sh dev

# Deploy the infrastructure
./scripts/deploy.sh dev
```
