import json
import os
import boto3
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

glue_client = boto3.client('glue')
sns_client = boto3.client('sns')

def lambda_handler(event, context):
    """Monitor Glue health check jobs"""
    
    try:
        job_name = event['job_name']
        job_run_id = event.get('job_run_id')
        
        # Get job status
        job_status = get_job_status(job_name, job_run_id)
        
        # Process status
        result = process_job_status(job_status)
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Monitor failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def get_job_status(job_name, job_run_id=None):
    """Get job status from Glue"""
    
    if job_run_id:
        response = glue_client.get_job_run(
            JobName=job_name,
            RunId=job_run_id
        )
        job_run = response['JobRun']
    else:
        response = glue_client.get_job_runs(
            JobName=job_name,
            MaxResults=1
        )
        job_run = response['JobRuns'][0]
    
    return {
        'job_name': job_name,
        'job_run_id': job_run['Id'],
        'state': job_run['JobRunState'],
        'error_message': job_run.get('ErrorMessage')
    }

def process_job_status(job_status):
    """Process job status and return result"""
    
    state = job_status['state']
    
    if state == 'SUCCEEDED':
        return {
            'status': 'PASS',
            'message': 'Health check passed'
        }
    elif state in ['FAILED', 'ERROR', 'TIMEOUT']:
        return {
            'status': 'FAIL',
            'message': f"Health check failed: {job_status.get('error_message', 'Unknown error')}"
        }
    else:
        return {
            'status': 'RUNNING',
            'message': 'Health check still running'
        }

def parse_monitor_event(event):
    """Parse monitoring event from various sources"""
    
    # Direct invocation with job info
    if 'job_name' in event:
        return event
    
    # EventBridge event for Glue job state changes
    elif 'source' in event and event['source'] == 'aws.glue':
        detail = event['detail']
        return {
            'job_name': detail['jobName'],
            'job_run_id': detail['jobRunId'],
            'state': detail['state'],
            'trigger_source': 'eventbridge'
        }
    
    # CloudWatch scheduled event
    elif 'source' in event and event['source'] == 'aws.events':
        # Extract job info from scheduled event
        job_name = event.get('job_name', '')
        return {
            'job_name': job_name,
            'trigger_source': 'scheduled'
        }
    
    else:
        raise ValueError("Unsupported monitor event format")

def handle_job_success(job_status, job_info):
    """Handle successful job completion"""
    
    logger.info("✅ Health check job succeeded")
    
    # Send success notification
    send_notification(
        subject="✅ Glue Health Check Passed",
        message=f"Health check job {job_status['job_name']} completed successfully",
        job_status=job_status,
        status="PASS"
    )
    
    # Trigger cleanup
    trigger_cleanup(job_status['job_name'])
    
    return {
        'status': 'SUCCEEDED',
        'action': 'success_processed',
        'message': 'Health check passed, cleanup triggered',
        'execution_time': job_status.get('execution_time')
    }

def handle_job_failure(job_status, job_info):
    """Handle failed job completion"""
    
    logger.error("❌ Health check job failed")
    
    # Send failure notification
    send_notification(
        subject="❌ Glue Health Check Failed",
        message=f"Health check job {job_status['job_name']} failed: {job_status.get('error_message', 'Unknown error')}",
        job_status=job_status,
        status="FAIL"
    )
    
    # Trigger cleanup
    trigger_cleanup(job_status['job_name'])
    
    return {
        'status': job_status['state'],
        'action': 'failure_processed',
        'message': f"Health check failed: {job_status.get('error_message', 'Unknown error')}",
        'error_message': job_status.get('error_message')
    }

def handle_job_running(job_status, job_info):
    """Handle running job"""
    
    logger.info("⏳ Health check job still running")
    
    # Check for timeout
    started_on = job_status.get('started_on')
    timeout = job_status.get('timeout', 30)  # Default 30 minutes
    
    if started_on:
        runtime_minutes = (datetime.now() - started_on.replace(tzinfo=None)).total_seconds() / 60
        if runtime_minutes > timeout:
            # Job is running too long, stop it
            try:
                glue_client.batch_stop_job_run(
                    JobName=job_status['job_name'],
                    JobRunsToStop=[job_status['job_run_id']]
                )
                logger.warning(f"⏰ Stopped job due to timeout: {runtime_minutes:.1f} minutes")
                
                return {
                    'status': 'TIMEOUT',
                    'action': 'stopped_due_to_timeout',
                    'message': f'Job stopped after {runtime_minutes:.1f} minutes'
                }
            except Exception as e:
                logger.error(f"Failed to stop job: {e}")
    
    return {
        'status': 'RUNNING',
        'action': 'continue_monitoring',
        'message': 'Job still running, will check again',
        'next_check': '5_minutes'
    }

def handle_job_stopped(job_status, job_info):
    """Handle stopped job"""
    
    logger.warning("🛑 Health check job was stopped")
    
    send_notification(
        subject="🛑 Glue Health Check Stopped",
        message=f"Health check job {job_status['job_name']} was stopped",
        job_status=job_status,
        status="STOPPED"
    )
    
    trigger_cleanup(job_status['job_name'])
    
    return {
        'status': 'STOPPED',
        'action': 'stopped_processed',
        'message': 'Job was stopped, cleanup triggered'
    }

def send_notification(subject, message, job_status, status):
    """Send notification about job status"""
    
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    webhook_url = os.environ.get('WEBHOOK_URL')
    
    notification_data = {
        'subject': subject,
        'message': message,
        'job_name': job_status['job_name'],
        'job_run_id': job_status['job_run_id'],
        'status': status,
        'timestamp': datetime.now().isoformat(),
        'execution_time': job_status.get('execution_time'),
        'error_message': job_status.get('error_message')
    }
    
    # Send SNS notification
    if topic_arn:
        try:
            sns_client.publish(
                TopicArn=topic_arn,
                Message=json.dumps(notification_data, default=str),
                Subject=subject
            )
            logger.info(f"📧 Sent SNS notification: {status}")
        except Exception as e:
            logger.warning(f"⚠️ Failed to send SNS notification: {e}")
    
    # Send webhook notification (for CI/CD integration)
    if webhook_url:
        try:
            import urllib3
            http = urllib3.PoolManager()
            
            response = http.request(
                'POST',
                webhook_url,
                body=json.dumps(notification_data, default=str),
                headers={'Content-Type': 'application/json'}
            )
            logger.info(f"🔗 Sent webhook notification: {response.status}")
        except Exception as e:
            logger.warning(f"⚠️ Failed to send webhook: {e}")

def trigger_cleanup(job_name):
    """Trigger cleanup Lambda function"""
    
    cleanup_function = os.environ.get('CLEANUP_FUNCTION_NAME')
    if not cleanup_function:
        logger.warning("⚠️ No cleanup function configured")
        return
    
    try:
        lambda_client = boto3.client('lambda')
        
        payload = {
            'job_name': job_name,
            'cleanup_type': 'health_check',
            'timestamp': datetime.now().isoformat()
        }
        
        lambda_client.invoke(
            FunctionName=cleanup_function,
            InvocationType='Event',  # Async
            Payload=json.dumps(payload)
        )
        
        logger.info(f"🧹 Triggered cleanup for job: {job_name}")
    except Exception as e:
        logger.warning(f"⚠️ Failed to trigger cleanup: {e}") 