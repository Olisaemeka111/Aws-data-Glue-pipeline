#!/usr/bin/env python3
"""
Lambda Function: Glue Health Check Trigger
Receives CI/CD webhooks and triggers Glue health check jobs
"""

import json
import os
import boto3
import logging
from datetime import datetime
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
glue_client = boto3.client('glue')
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for triggering Glue health check jobs
    
    Expected event format:
    {
        "pr_number": "123",
        "branch": "feature/new-feature",
        "script_location": "s3://bucket/scripts/job.py",
        "job_arguments": {"--enable-metrics": "true"}
    }
    """
    
    try:
        logger.info(f"🔄 Health check trigger received: {json.dumps(event, default=str)}")
        
        # Parse request
        request_data = parse_request(event)
        
        # Validate request
        validate_request(request_data)
        
        # Generate unique job identifier
        job_suffix = f"pr-{request_data['pr_number']}-{int(datetime.now().timestamp())}"
        job_name = f"glue-health-check-{job_suffix}"
        
        logger.info(f"🚀 Starting health check job: {job_name}")
        
        # Start Glue job
        job_run_id = start_glue_health_check(job_name, request_data, job_suffix)
        
        # Store job metadata for monitoring
        store_job_metadata(job_suffix, {
            'job_name': job_name,
            'job_run_id': job_run_id,
            'pr_number': request_data['pr_number'],
            'branch': request_data['branch'],
            'script_location': request_data['script_location'],
            'started_at': datetime.now().isoformat(),
            'status': 'RUNNING'
        })
        
        # Send notification
        send_notification(
            topic='health-check-started',
            message=f"Health check started for PR #{request_data['pr_number']}",
            job_name=job_name,
            job_run_id=job_run_id
        )
        
        # Return success response
        response = {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'message': 'Health check job started successfully',
                'job_name': job_name,
                'job_run_id': job_run_id,
                'job_suffix': job_suffix,
                'monitor_url': f"https://console.aws.amazon.com/glue/home#etl:tab=jobs;jobName={job_name};jobRunId={job_run_id}"
            })
        }
        
        logger.info(f"✅ Health check trigger completed successfully")
        return response
        
    except Exception as e:
        logger.error(f"❌ Health check trigger failed: {str(e)}")
        
        # Send failure notification
        try:
            send_notification(
                topic='health-check-failed',
                message=f"Health check trigger failed: {str(e)}",
                error=str(e)
            )
        except:
            pass
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'message': f'Health check trigger failed: {str(e)}'
            })
        }

def parse_request(event: Dict[str, Any]) -> Dict[str, Any]:
    """Parse incoming request from various sources"""
    
    # Handle API Gateway requests
    if 'body' in event:
        if isinstance(event['body'], str):
            body = json.loads(event['body'])
        else:
            body = event['body']
        return body
    
    # Handle direct Lambda invocation
    elif 'pr_number' in event:
        return event
    
    # Handle S3 event (script upload)
    elif 'Records' in event and event['Records'][0]['eventSource'] == 'aws:s3':
        s3_record = event['Records'][0]['s3']
        bucket = s3_record['bucket']['name']
        key = s3_record['object']['key']
        
        # Extract PR info from S3 key (e.g., health-check/pr-123/script.py)
        key_parts = key.split('/')
        pr_number = key_parts[1].replace('pr-', '') if len(key_parts) > 1 else 'unknown'
        
        return {
            'pr_number': pr_number,
            'branch': 'auto-detected',
            'script_location': f's3://{bucket}/{key}',
            'trigger_source': 's3'
        }
    
    # Handle webhook from CI/CD systems
    elif 'pull_request' in event:
        # GitHub webhook format
        pr = event['pull_request']
        return {
            'pr_number': str(pr['number']),
            'branch': pr['head']['ref'],
            'script_location': event.get('script_location', ''),
            'trigger_source': 'github'
        }
    
    else:
        raise ValueError(f"Unsupported event format: {event}")

def validate_request(request_data: Dict[str, Any]) -> None:
    """Validate request data"""
    
    required_fields = ['pr_number', 'script_location']
    for field in required_fields:
        if not request_data.get(field):
            raise ValueError(f"Missing required field: {field}")
    
    # Validate S3 script location
    script_location = request_data['script_location']
    if not script_location.startswith('s3://'):
        raise ValueError(f"Invalid script location: {script_location}")

def start_glue_health_check(job_name: str, request_data: Dict[str, Any], job_suffix: str) -> str:
    """Start Glue health check job"""
    
    default_args = {
        '--health-check-mode': 'true',
        '--stub-data-sources': 'true',
        '--dry-run': 'true'
    }
    
    try:
        response = glue_client.start_job_run(
            JobName=job_name,
            Arguments=default_args,
            MaxCapacity=2,
            Timeout=30
        )
        
        return response['JobRunId']
        
    except glue_client.exceptions.EntityNotFoundException:
        # Create job if it doesn't exist
        create_health_check_job(job_name, request_data['script_location'])
        
        # Try starting again
        response = glue_client.start_job_run(
            JobName=job_name,
            Arguments=default_args,
            MaxCapacity=2,
            Timeout=30
        )
        
        return response['JobRunId']

def create_health_check_job(job_name: str, script_location: str) -> None:
    """Create Glue health check job"""
    
    glue_role_arn = os.environ.get('GLUE_ROLE_ARN')
    
    glue_client.create_job(
        Name=job_name,
        Role=glue_role_arn,
        Command={
            'Name': 'glueetl',
            'ScriptLocation': script_location,
            'PythonVersion': '3'
        },
        MaxCapacity=2,
        Timeout=30,
        GlueVersion='4.0'
    )

def store_job_metadata(job_suffix: str, metadata: Dict[str, Any]) -> None:
    """Store job metadata in S3 for monitoring"""
    
    bucket = os.environ.get('METADATA_BUCKET', 'glue-health-check-metadata')
    key = f'job-metadata/{job_suffix}.json'
    
    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=json.dumps(metadata, default=str),
            ContentType='application/json',
            Metadata={
                'job-suffix': job_suffix,
                'created-at': datetime.now().isoformat()
            }
        )
        logger.info(f"📁 Stored job metadata: s3://{bucket}/{key}")
    except Exception as e:
        logger.warning(f"⚠️ Failed to store metadata: {e}")

def send_notification(topic: str, message: str, **kwargs) -> None:
    """Send SNS notification"""
    
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if not topic_arn:
        logger.warning("⚠️ No SNS topic configured, skipping notification")
        return
    
    try:
        notification_data = {
            'topic': topic,
            'message': message,
            'timestamp': datetime.now().isoformat(),
            **kwargs
        }
        
        sns_client.publish(
            TopicArn=topic_arn,
            Message=json.dumps(notification_data, default=str),
            Subject=f"Glue Health Check: {topic}"
        )
        logger.info(f"📧 Sent notification: {topic}")
    except Exception as e:
        logger.warning(f"⚠️ Failed to send notification: {e}")

def get_environment_config() -> Dict[str, str]:
    """Get environment configuration"""
    return {
        'glue_role_arn': os.environ.get('GLUE_ROLE_ARN', ''),
        'temp_bucket': os.environ.get('TEMP_BUCKET', 'glue-health-check-temp'),
        'metadata_bucket': os.environ.get('METADATA_BUCKET', 'glue-health-check-metadata'),
        'sns_topic_arn': os.environ.get('SNS_TOPIC_ARN', ''),
        'max_job_timeout': int(os.environ.get('MAX_JOB_TIMEOUT', '30')),
        'max_capacity': float(os.environ.get('MAX_CAPACITY', '2'))
    }

# For local testing
if __name__ == "__main__":
    # Test event
    test_event = {
        "pr_number": "123",
        "branch": "feature/test",
        "script_location": "s3://test-bucket/scripts/test_job.py",
        "job_arguments": {
            "--enable-debug": "true"
        }
    }
    
    class MockContext:
        def __init__(self):
            self.function_name = "test-function"
            self.aws_request_id = "test-request-id"
    
    result = lambda_handler(test_event, MockContext())
    print(json.dumps(result, indent=2)) 