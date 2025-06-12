import json
import boto3
import os
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
cloudwatch = boto3.client('cloudwatch')
glue = boto3.client('glue')
sns = boto3.client('sns')
dynamodb = boto3.client('dynamodb')

# Environment variables
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
GLUE_JOBS = os.environ.get('GLUE_JOBS', '').split(',')

def get_job_metrics(job_name, start_time, end_time):
    """Get CloudWatch metrics for a Glue job."""
    metrics = {}
    
    # Get job duration
    duration_response = cloudwatch.get_metric_statistics(
        Namespace='Glue',
        MetricName='glue.driver.aggregate.elapsedTime',
        Dimensions=[{'Name': 'JobName', 'Value': job_name}],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,
        Statistics=['Maximum']
    )
    
    if duration_response['Datapoints']:
        metrics['duration_ms'] = max([point['Maximum'] for point in duration_response['Datapoints']])
        metrics['duration_minutes'] = round(metrics['duration_ms'] / (1000 * 60), 2)
    
    # Get memory usage
    memory_response = cloudwatch.get_metric_statistics(
        Namespace='Glue',
        MetricName='glue.driver.jvm.heap.usage',
        Dimensions=[{'Name': 'JobName', 'Value': job_name}],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,
        Statistics=['Maximum']
    )
    
    if memory_response['Datapoints']:
        metrics['memory_usage_percent'] = max([point['Maximum'] for point in memory_response['Datapoints']])
    
    # Get data processed
    read_response = cloudwatch.get_metric_statistics(
        Namespace='Glue',
        MetricName='glue.ALL.s3.filesystem.read_bytes',
        Dimensions=[{'Name': 'JobName', 'Value': job_name}],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,
        Statistics=['Sum']
    )
    
    if read_response['Datapoints']:
        metrics['read_bytes'] = sum([point['Sum'] for point in read_response['Datapoints']])
        metrics['read_mb'] = round(metrics['read_bytes'] / (1024 * 1024), 2)
    
    write_response = cloudwatch.get_metric_statistics(
        Namespace='Glue',
        MetricName='glue.ALL.s3.filesystem.write_bytes',
        Dimensions=[{'Name': 'JobName', 'Value': job_name}],
        StartTime=start_time,
        EndTime=end_time,
        Period=300,
        Statistics=['Sum']
    )
    
    if write_response['Datapoints']:
        metrics['write_bytes'] = sum([point['Sum'] for point in write_response['Datapoints']])
        metrics['write_mb'] = round(metrics['write_bytes'] / (1024 * 1024), 2)
    
    return metrics

def get_job_state(job_name, state_table_name):
    """Get job state from DynamoDB."""
    try:
        response = dynamodb.get_item(
            TableName=state_table_name,
            Key={'job_name': {'S': job_name}}
        )
        
        if 'Item' in response:
            item = response['Item']
            state = {
                'status': item.get('status', {}).get('S'),
                'updated_at': item.get('updated_at', {}).get('S'),
                'message': item.get('message', {}).get('S')
            }
            
            if 'metadata' in item:
                try:
                    metadata = json.loads(item['metadata']['S'])
                    state['metadata'] = metadata
                except:
                    state['metadata'] = {}
            
            return state
        
        return None
    except Exception as e:
        logger.error(f"Error getting job state: {str(e)}")
        return None

def get_job_runs(job_name, start_time, max_results=10):
    """Get recent job runs for a Glue job."""
    try:
        response = glue.get_job_runs(
            JobName=job_name,
            MaxResults=max_results
        )
        
        job_runs = []
        for run in response.get('JobRuns', []):
            # Only include runs after start_time
            if run.get('StartedOn', datetime.now()) >= start_time:
                job_run = {
                    'id': run.get('Id'),
                    'start_time': run.get('StartedOn').isoformat() if 'StartedOn' in run else None,
                    'end_time': run.get('CompletedOn').isoformat() if 'CompletedOn' in run else None,
                    'status': run.get('JobRunState'),
                    'error_message': run.get('ErrorMessage', ''),
                    'trigger_name': run.get('TriggerName', ''),
                    'allocated_capacity': run.get('AllocatedCapacity'),
                    'execution_time': run.get('ExecutionTime')
                }
                job_runs.append(job_run)
        
        return job_runs
    except Exception as e:
        logger.error(f"Error getting job runs: {str(e)}")
        return []

def send_notification(subject, message):
    """Send SNS notification."""
    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        logger.info(f"Notification sent: {subject}")
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")

def format_job_report(job_name, job_runs, metrics, job_state):
    """Format job report for notification."""
    report = f"Job Name: {job_name}\n\n"
    
    # Add job state information
    if job_state:
        report += "Current State:\n"
        report += f"  Status: {job_state.get('status', 'Unknown')}\n"
        report += f"  Last Updated: {job_state.get('updated_at', 'Unknown')}\n"
        
        if job_state.get('message'):
            report += f"  Message: {job_state.get('message')}\n"
        
        if job_state.get('metadata'):
            report += "  Metadata:\n"
            for key, value in job_state.get('metadata', {}).items():
                report += f"    {key}: {value}\n"
        
        report += "\n"
    
    # Add metrics information
    if metrics:
        report += "Performance Metrics:\n"
        
        if 'duration_minutes' in metrics:
            report += f"  Duration: {metrics['duration_minutes']} minutes\n"
        
        if 'memory_usage_percent' in metrics:
            report += f"  Max Memory Usage: {metrics['memory_usage_percent']}%\n"
        
        if 'read_mb' in metrics:
            report += f"  Data Read: {metrics['read_mb']} MB\n"
        
        if 'write_mb' in metrics:
            report += f"  Data Written: {metrics['write_mb']} MB\n"
        
        report += "\n"
    
    # Add job runs information
    if job_runs:
        report += f"Recent Job Runs ({len(job_runs)}):\n"
        
        for i, run in enumerate(job_runs):
            report += f"  Run {i+1}:\n"
            report += f"    ID: {run.get('id', 'Unknown')}\n"
            report += f"    Status: {run.get('status', 'Unknown')}\n"
            
            if run.get('start_time'):
                report += f"    Started: {run.get('start_time')}\n"
            
            if run.get('end_time'):
                report += f"    Completed: {run.get('end_time')}\n"
            
            if run.get('execution_time'):
                report += f"    Execution Time: {run.get('execution_time')} seconds\n"
            
            if run.get('error_message'):
                report += f"    Error: {run.get('error_message')}\n"
            
            report += "\n"
    
    return report

def handler(event, context):
    """Lambda handler function."""
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Determine if this is an EventBridge event for Glue job state change
        is_glue_state_change = (
            event.get('source') == 'aws.glue' and
            event.get('detail-type') == 'Glue Job State Change'
        )
        
        # Set time window for metrics
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=1)
        
        if is_glue_state_change:
            # Process Glue job state change event
            job_name = event.get('detail', {}).get('jobName')
            job_state = event.get('detail', {}).get('state')
            
            if not job_name or not job_state:
                logger.warning("Missing job name or state in event")
                return {
                    'statusCode': 400,
                    'body': 'Missing job name or state in event'
                }
            
            # Only process completed or failed jobs
            if job_state not in ['SUCCEEDED', 'FAILED']:
                logger.info(f"Ignoring job state: {job_state}")
                return {
                    'statusCode': 200,
                    'body': f'Ignoring job state: {job_state}'
                }
            
            # Get job metrics
            metrics = get_job_metrics(job_name, start_time, end_time)
            
            # Get recent job runs
            job_runs = get_job_runs(job_name, start_time)
            
            # Get job state from DynamoDB
            state_table_name = f"glue-etl-pipeline-{ENVIRONMENT}-job-state"
            job_state_data = get_job_state(job_name, state_table_name)
            
            # Format job report
            report = format_job_report(job_name, job_runs, metrics, job_state_data)
            
            # Send notification
            status_text = "Succeeded" if job_state == "SUCCEEDED" else "Failed"
            subject = f"[{ENVIRONMENT.upper()}] Glue Job {status_text}: {job_name}"
            send_notification(subject, report)
            
            return {
                'statusCode': 200,
                'body': f'Processed job state change for {job_name}'
            }
        else:
            # Process scheduled event (daily summary)
            logger.info("Processing scheduled event for daily summary")
            
            for job_name in GLUE_JOBS:
                if not job_name:
                    continue
                
                # Get job metrics
                metrics = get_job_metrics(job_name, start_time, end_time)
                
                # Get recent job runs
                job_runs = get_job_runs(job_name, start_time)
                
                # Get job state from DynamoDB
                state_table_name = f"glue-etl-pipeline-{ENVIRONMENT}-job-state"
                job_state_data = get_job_state(job_name, state_table_name)
                
                # Format job report
                report = format_job_report(job_name, job_runs, metrics, job_state_data)
                
                # Send notification
                subject = f"[{ENVIRONMENT.upper()}] Daily Summary: {job_name}"
                send_notification(subject, report)
            
            return {
                'statusCode': 200,
                'body': f'Processed daily summary for {len(GLUE_JOBS)} jobs'
            }
    
    except Exception as e:
        error_message = str(e)
        logger.error(f"Error processing event: {error_message}")
        
        # Send error notification
        subject = f"[{ENVIRONMENT.upper()}] Monitoring Error"
        message = f"Error processing monitoring event:\n\n{error_message}\n\nEvent: {json.dumps(event)}"
        send_notification(subject, message)
        
        return {
            'statusCode': 500,
            'body': f'Error: {error_message}'
        }
