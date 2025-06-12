"""
Lambda function to trigger Glue ETL pipeline when new data is injected into the data source.
Includes security scanning of incoming data before pipeline execution.
"""
import os
import json
import boto3
import urllib.parse
import logging
import hashlib
import re
import time
from datetime import datetime
from typing import Dict, List, Any, Tuple, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
glue_client = boto3.client('glue')
sns_client = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
securityhub_client = boto3.client('securityhub')

# Environment variables
GLUE_WORKFLOW_NAME = os.environ.get('GLUE_WORKFLOW_NAME')
SECURITY_SNS_TOPIC = os.environ.get('SECURITY_SNS_TOPIC')
SCAN_RESULTS_TABLE = os.environ.get('SCAN_RESULTS_TABLE')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
MAX_FILE_SIZE_MB = int(os.environ.get('MAX_FILE_SIZE_MB', '100'))
ALLOWED_FILE_TYPES = os.environ.get('ALLOWED_FILE_TYPES', 'csv,json,parquet,avro').split(',')
SENSITIVE_DATA_PATTERNS = {
    'credit_card': r'\b(?:\d{4}[-\s]?){3}\d{4}\b',
    'ssn': r'\b\d{3}-\d{2}-\d{4}\b',
    'api_key': r'\b[A-Za-z0-9]{32,}\b',
    'password': r'\b(?:password|passwd|pwd)[\s:=]+\S+\b',
    'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
}

class SecurityScanResult:
    """Class to store security scan results"""
    def __init__(self, file_key: str, bucket: str):
        self.file_key = file_key
        self.bucket = bucket
        self.timestamp = datetime.utcnow().isoformat()
        self.scan_id = hashlib.md5(f"{bucket}:{file_key}:{self.timestamp}".encode()).hexdigest()
        self.issues = []
        self.status = "SCANNING"
        self.severity = "INFORMATIONAL"
    
    def add_issue(self, issue_type: str, description: str, severity: str = "MEDIUM"):
        """Add a security issue to the scan results"""
        self.issues.append({
            "type": issue_type,
            "description": description,
            "severity": severity
        })
        # Update overall severity based on highest issue severity
        severity_levels = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}
        if severity_levels.get(severity, 0) > severity_levels.get(self.severity, 0):
            self.severity = severity
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert scan result to dictionary"""
        return {
            "scan_id": self.scan_id,
            "file_key": self.file_key,
            "bucket": self.bucket,
            "timestamp": self.timestamp,
            "issues": self.issues,
            "status": self.status,
            "severity": self.severity
        }

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler function to process S3 events and trigger Glue workflow
    after performing security scans on the incoming data.
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Process S3 event
        if 'Records' not in event:
            logger.error("No Records found in event")
            return {"statusCode": 400, "body": "No Records found in event"}
        
        # Track files that passed security scan
        safe_files = []
        blocked_files = []
        
        # Process each record in the event
        for record in event['Records']:
            if record['eventSource'] != 'aws:s3' or 'ObjectCreated' not in record['eventName']:
                continue
                
            bucket = record['s3']['bucket']['name']
            key = urllib.parse.unquote_plus(record['s3']['object']['key'])
            
            logger.info(f"Processing new file: s3://{bucket}/{key}")
            
            # Perform security scan on the file
            scan_result = security_scan_file(bucket, key)
            
            # Save scan results to DynamoDB
            save_scan_result(scan_result)
            
            # Report to Security Hub if issues found
            if scan_result.issues:
                report_to_security_hub(scan_result)
                
            # Determine if file is safe to process
            if scan_result.status == "BLOCKED":
                blocked_files.append(key)
                send_security_alert(scan_result)
            else:
                safe_files.append(key)
        
        # Log results
        logger.info(f"Security scan complete. Safe files: {len(safe_files)}, Blocked files: {len(blocked_files)}")
        
        # Only trigger Glue workflow if there are safe files to process
        if safe_files and GLUE_WORKFLOW_NAME:
            trigger_glue_workflow(safe_files)
            return {
                "statusCode": 200,
                "body": f"Successfully triggered Glue workflow for {len(safe_files)} files. {len(blocked_files)} files were blocked."
            }
        elif blocked_files and not safe_files:
            return {
                "statusCode": 403,
                "body": f"All {len(blocked_files)} files were blocked due to security issues."
            }
        else:
            return {
                "statusCode": 200,
                "body": "No files to process or workflow name not configured."
            }
            
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}", exc_info=True)
        return {"statusCode": 500, "body": f"Error: {str(e)}"}

def security_scan_file(bucket: str, key: str) -> SecurityScanResult:
    """
    Perform security scan on the file to detect potential issues.
    
    Checks:
    1. File size validation
    2. File type validation
    3. Malware scanning (simulated)
    4. Sensitive data detection
    5. File integrity check
    """
    scan_result = SecurityScanResult(key, bucket)
    
    try:
        # Get file metadata
        response = s3_client.head_object(Bucket=bucket, Key=key)
        file_size_mb = response['ContentLength'] / (1024 * 1024)
        content_type = response.get('ContentType', '')
        
        # 1. File size validation
        if file_size_mb > MAX_FILE_SIZE_MB:
            scan_result.add_issue(
                "OVERSIZED_FILE", 
                f"File size ({file_size_mb:.2f} MB) exceeds maximum allowed size ({MAX_FILE_SIZE_MB} MB)",
                "MEDIUM"
            )
        
        # 2. File type validation
        file_extension = key.split('.')[-1].lower() if '.' in key else ''
        if file_extension not in ALLOWED_FILE_TYPES:
            scan_result.add_issue(
                "INVALID_FILE_TYPE",
                f"File type '{file_extension}' is not in the allowed list: {', '.join(ALLOWED_FILE_TYPES)}",
                "HIGH"
            )
        
        # 3. Simulated malware scan
        # In a real implementation, this would call an actual malware scanning service
        if simulate_malware_scan(bucket, key):
            scan_result.add_issue(
                "POTENTIAL_MALWARE",
                "Potential malware signature detected in file",
                "CRITICAL"
            )
        
        # 4. Sensitive data detection
        # For large files, we might want to sample the content
        if file_size_mb < 10:  # Only scan files smaller than 10MB for sensitive data
            sensitive_data = detect_sensitive_data(bucket, key)
            for data_type, count in sensitive_data.items():
                if count > 0:
                    scan_result.add_issue(
                        "SENSITIVE_DATA_DETECTED",
                        f"Detected {count} instances of {data_type}",
                        "HIGH"
                    )
        
        # 5. File integrity check
        if not check_file_integrity(bucket, key):
            scan_result.add_issue(
                "FILE_INTEGRITY_ISSUE",
                "File integrity check failed",
                "MEDIUM"
            )
        
        # Set final status
        if any(issue['severity'] in ['HIGH', 'CRITICAL'] for issue in scan_result.issues):
            scan_result.status = "BLOCKED"
        elif scan_result.issues:
            scan_result.status = "WARNING"
        else:
            scan_result.status = "CLEAN"
            
        # Log scan result
        logger.info(f"Security scan completed for s3://{bucket}/{key}: {scan_result.status}")
        
        return scan_result
        
    except Exception as e:
        logger.error(f"Error during security scan of s3://{bucket}/{key}: {str(e)}", exc_info=True)
        scan_result.add_issue(
            "SCAN_ERROR",
            f"Error during security scan: {str(e)}",
            "HIGH"
        )
        scan_result.status = "ERROR"
        return scan_result

def simulate_malware_scan(bucket: str, key: str) -> bool:
    """
    Simulate a malware scan. In a real implementation, this would call
    an actual malware scanning service like ClamAV or a managed service.
    """
    # This is a placeholder that randomly flags ~1% of files
    # In a real implementation, you would integrate with a proper malware scanning service
    import random
    return random.random() < 0.01

def detect_sensitive_data(bucket: str, key: str) -> Dict[str, int]:
    """
    Scan file content for sensitive data patterns
    """
    result = {pattern_name: 0 for pattern_name in SENSITIVE_DATA_PATTERNS}
    
    try:
        # Get file content
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        
        # Check each pattern
        for pattern_name, regex in SENSITIVE_DATA_PATTERNS.items():
            matches = re.findall(regex, content)
            result[pattern_name] = len(matches)
        
        return result
    except Exception as e:
        logger.error(f"Error scanning for sensitive data: {str(e)}", exc_info=True)
        return result

def check_file_integrity(bucket: str, key: str) -> bool:
    """
    Check file integrity by verifying it can be properly read
    """
    try:
        # Try to read the first few bytes of the file
        response = s3_client.get_object(Bucket=bucket, Key=key)
        response['Body'].read(1024)
        return True
    except Exception as e:
        logger.error(f"File integrity check failed: {str(e)}", exc_info=True)
        return False

def save_scan_result(scan_result: SecurityScanResult) -> None:
    """
    Save scan result to DynamoDB
    """
    if not SCAN_RESULTS_TABLE:
        logger.warning("SCAN_RESULTS_TABLE environment variable not set, skipping result storage")
        return
        
    try:
        table = dynamodb.Table(SCAN_RESULTS_TABLE)
        table.put_item(Item=scan_result.to_dict())
        logger.info(f"Saved scan result to DynamoDB: {scan_result.scan_id}")
    except Exception as e:
        logger.error(f"Error saving scan result to DynamoDB: {str(e)}", exc_info=True)

def send_security_alert(scan_result: SecurityScanResult) -> None:
    """
    Send security alert notification via SNS
    """
    if not SECURITY_SNS_TOPIC:
        logger.warning("SECURITY_SNS_TOPIC environment variable not set, skipping alert")
        return
        
    try:
        message = {
            "subject": f"[{ENVIRONMENT.upper()}] Security Scan Alert: {scan_result.severity} issues detected",
            "message": (
                f"Security issues detected in file s3://{scan_result.bucket}/{scan_result.file_key}\n"
                f"Scan ID: {scan_result.scan_id}\n"
                f"Timestamp: {scan_result.timestamp}\n"
                f"Severity: {scan_result.severity}\n"
                f"Status: {scan_result.status}\n\n"
                "Issues:\n" + 
                "\n".join([f"- {issue['type']} ({issue['severity']}): {issue['description']}" 
                          for issue in scan_result.issues])
            ),
            "scan_result": scan_result.to_dict()
        }
        
        sns_client.publish(
            TopicArn=SECURITY_SNS_TOPIC,
            Message=json.dumps(message),
            Subject=message["subject"]
        )
        logger.info(f"Security alert sent for scan {scan_result.scan_id}")
    except Exception as e:
        logger.error(f"Error sending security alert: {str(e)}", exc_info=True)

def report_to_security_hub(scan_result: SecurityScanResult) -> None:
    """
    Report security findings to AWS Security Hub
    """
    try:
        # Map severity to Security Hub severity
        severity_map = {
            "LOW": {"Label": "LOW", "Normalized": 20},
            "MEDIUM": {"Label": "MEDIUM", "Normalized": 40},
            "HIGH": {"Label": "HIGH", "Normalized": 70},
            "CRITICAL": {"Label": "CRITICAL", "Normalized": 90}
        }
        
        # Create finding for each issue
        for issue in scan_result.issues:
            severity = severity_map.get(issue["severity"], severity_map["MEDIUM"])
            
            finding = {
                "SchemaVersion": "2018-10-08",
                "Id": f"{scan_result.scan_id}-{issue['type']}",
                "ProductArn": f"arn:aws:securityhub:{os.environ.get('AWS_REGION', 'us-east-1')}::product/custom/glue-etl-security",
                "GeneratorId": "GlueETLDataTrigger",
                "AwsAccountId": context.invoked_function_arn.split(":")[4],
                "Types": ["Software and Configuration Checks/Vulnerabilities/Data Exposure"],
                "CreatedAt": scan_result.timestamp,
                "UpdatedAt": scan_result.timestamp,
                "Severity": severity,
                "Title": f"{issue['type']} detected in S3 file",
                "Description": issue["description"],
                "ProductFields": {
                    "file_key": scan_result.file_key,
                    "bucket": scan_result.bucket,
                    "scan_id": scan_result.scan_id
                },
                "Resources": [
                    {
                        "Type": "AwsS3Object",
                        "Id": f"arn:aws:s3:::{scan_result.bucket}/{scan_result.file_key}",
                        "Partition": "aws",
                        "Region": os.environ.get('AWS_REGION', 'us-east-1')
                    }
                ],
                "Workflow": {"Status": "NEW"},
                "RecordState": "ACTIVE"
            }
            
            securityhub_client.batch_import_findings(Findings=[finding])
        
        logger.info(f"Reported {len(scan_result.issues)} findings to Security Hub for scan {scan_result.scan_id}")
    except Exception as e:
        logger.error(f"Error reporting to Security Hub: {str(e)}", exc_info=True)

def trigger_glue_workflow(file_keys: List[str]) -> None:
    """
    Trigger Glue workflow with the list of safe files
    """
    try:
        logger.info(f"Triggering Glue workflow: {GLUE_WORKFLOW_NAME}")
        
        # Start the Glue workflow with parameters
        response = glue_client.start_workflow_run(
            Name=GLUE_WORKFLOW_NAME,
            RunProperties={
                'processed_files': json.dumps(file_keys),
                'trigger_time': datetime.utcnow().isoformat(),
                'environment': ENVIRONMENT
            }
        )
        
        run_id = response.get('RunId')
        logger.info(f"Glue workflow triggered successfully. Run ID: {run_id}")
        
        # Record metric for successful trigger
        cloudwatch.put_metric_data(
            Namespace='GlueETLPipeline',
            MetricData=[
                {
                    'MetricName': 'WorkflowTriggerCount',
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': ENVIRONMENT},
                        {'Name': 'WorkflowName', 'Value': GLUE_WORKFLOW_NAME}
                    ],
                    'Value': 1,
                    'Unit': 'Count'
                },
                {
                    'MetricName': 'FilesProcessed',
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': ENVIRONMENT},
                        {'Name': 'WorkflowName', 'Value': GLUE_WORKFLOW_NAME}
                    ],
                    'Value': len(file_keys),
                    'Unit': 'Count'
                }
            ]
        )
        
    except Exception as e:
        logger.error(f"Error triggering Glue workflow: {str(e)}", exc_info=True)
        raise
