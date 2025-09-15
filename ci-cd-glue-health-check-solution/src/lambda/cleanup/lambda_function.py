import json
import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

glue_client = boto3.client('glue')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """Cleanup health check resources"""
    
    try:
        logger.info("🧹 Starting cleanup process")
        
        # Parse cleanup request
        job_name = event.get('job_name')
        job_suffix = event.get('job_suffix')
        cleanup_type = event.get('cleanup_type', 'full')
        
        if not job_name and not job_suffix:
            raise ValueError("Either job_name or job_suffix must be provided")
        
        # Determine job name if only suffix provided
        if not job_name and job_suffix:
            job_name = f"glue-health-check-{job_suffix}"
        
        # Determine suffix if only job name provided
        if not job_suffix and job_name:
            job_suffix = job_name.replace('glue-health-check-', '')
        
        logger.info(f"🎯 Cleaning up resources for: {job_name}")
        
        # Perform cleanup
        cleanup_results = perform_cleanup(job_name, job_suffix, cleanup_type)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'message': 'Cleanup completed successfully',
                'job_name': job_name,
                'job_suffix': job_suffix,
                'cleanup_results': cleanup_results
            })
        }
        
    except Exception as e:
        logger.error(f"❌ Cleanup failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'message': str(e)
            })
        }

def perform_cleanup(job_name, job_suffix, cleanup_type):
    """Perform the actual cleanup operations"""
    
    results = {
        'glue_job': 'not_attempted',
        's3_scripts': 'not_attempted',
        's3_metadata': 'not_attempted',
        'logs': 'not_attempted'
    }
    
    # 1. Clean up Glue job
    try:
        cleanup_glue_job(job_name)
        results['glue_job'] = 'success'
        logger.info(f"✅ Cleaned up Glue job: {job_name}")
    except Exception as e:
        logger.warning(f"⚠️ Failed to cleanup Glue job: {e}")
        results['glue_job'] = f'failed: {str(e)}'
    
    # 2. Clean up S3 scripts
    try:
        cleanup_s3_scripts(job_suffix)
        results['s3_scripts'] = 'success'
        logger.info(f"✅ Cleaned up S3 scripts for: {job_suffix}")
    except Exception as e:
        logger.warning(f"⚠️ Failed to cleanup S3 scripts: {e}")
        results['s3_scripts'] = f'failed: {str(e)}'
    
    # 3. Clean up metadata
    try:
        cleanup_metadata(job_suffix)
        results['s3_metadata'] = 'success'
        logger.info(f"✅ Cleaned up metadata for: {job_suffix}")
    except Exception as e:
        logger.warning(f"⚠️ Failed to cleanup metadata: {e}")
        results['s3_metadata'] = f'failed: {str(e)}'
    
    # 4. Clean up CloudWatch logs (optional)
    if cleanup_type == 'full':
        try:
            cleanup_logs(job_name)
            results['logs'] = 'success'
            logger.info(f"✅ Cleaned up logs for: {job_name}")
        except Exception as e:
            logger.warning(f"⚠️ Failed to cleanup logs: {e}")
            results['logs'] = f'failed: {str(e)}'
    
    return results

def cleanup_glue_job(job_name):
    """Delete Glue job"""
    
    try:
        # First, stop any running job runs
        response = glue_client.get_job_runs(
            JobName=job_name,
            MaxResults=10
        )
        
        running_jobs = [
            job_run['Id'] for job_run in response['JobRuns']
            if job_run['JobRunState'] in ['RUNNING', 'STARTING']
        ]
        
        if running_jobs:
            logger.info(f"🛑 Stopping {len(running_jobs)} running job runs")
            glue_client.batch_stop_job_run(
                JobName=job_name,
                JobRunsToStop=running_jobs
            )
            
            # Wait a moment for jobs to stop
            import time
            time.sleep(5)
        
        # Delete the job
        glue_client.delete_job(JobName=job_name)
        logger.info(f"🗑️ Deleted Glue job: {job_name}")
        
    except glue_client.exceptions.EntityNotFoundException:
        logger.info(f"ℹ️ Glue job not found (already deleted): {job_name}")
    except Exception as e:
        logger.error(f"❌ Failed to delete Glue job {job_name}: {e}")
        raise

def cleanup_s3_scripts(job_suffix):
    """Clean up S3 scripts for health check"""
    
    scripts_bucket = os.environ.get('SCRIPTS_BUCKET', 'glue-health-check-scripts')
    prefix = f'health-check/{job_suffix}/'
    
    try:
        # List objects with the prefix
        response = s3_client.list_objects_v2(
            Bucket=scripts_bucket,
            Prefix=prefix
        )
        
        if 'Contents' not in response:
            logger.info(f"ℹ️ No S3 scripts found for prefix: {prefix}")
            return
        
        # Delete objects
        objects_to_delete = [{'Key': obj['Key']} for obj in response['Contents']]
        
        if objects_to_delete:
            s3_client.delete_objects(
                Bucket=scripts_bucket,
                Delete={'Objects': objects_to_delete}
            )
            logger.info(f"🗑️ Deleted {len(objects_to_delete)} S3 objects from {scripts_bucket}/{prefix}")
        
    except Exception as e:
        logger.error(f"❌ Failed to cleanup S3 scripts: {e}")
        raise

def cleanup_metadata(job_suffix):
    """Clean up job metadata"""
    
    metadata_bucket = os.environ.get('METADATA_BUCKET', 'glue-health-check-metadata')
    key = f'job-metadata/{job_suffix}.json'
    
    try:
        s3_client.delete_object(
            Bucket=metadata_bucket,
            Key=key
        )
        logger.info(f"🗑️ Deleted metadata: s3://{metadata_bucket}/{key}")
        
    except s3_client.exceptions.NoSuchKey:
        logger.info(f"ℹ️ Metadata file not found: {key}")
    except Exception as e:
        logger.error(f"❌ Failed to cleanup metadata: {e}")
        raise

def cleanup_logs(job_name):
    """Clean up CloudWatch logs (optional)"""
    
    logs_client = boto3.client('logs')
    log_group_name = f'/aws-glue/health-check/{job_name}'
    
    try:
        logs_client.delete_log_group(logGroupName=log_group_name)
        logger.info(f"🗑️ Deleted log group: {log_group_name}")
        
    except logs_client.exceptions.ResourceNotFoundException:
        logger.info(f"ℹ️ Log group not found: {log_group_name}")
    except Exception as e:
        logger.error(f"❌ Failed to cleanup logs: {e}")
        raise

def cleanup_by_age():
    """Clean up old health check resources (for scheduled cleanup)"""
    
    from datetime import datetime, timedelta
    
    cutoff_date = datetime.now() - timedelta(hours=24)  # Cleanup resources older than 24 hours
    
    try:
        # Get all health check jobs
        paginator = glue_client.get_paginator('get_jobs')
        
        for page in paginator.paginate():
            for job in page['Jobs']:
                job_name = job['Name']
                
                # Only process health check jobs
                if not job_name.startswith('glue-health-check-'):
                    continue
                
                # Check job creation time from tags
                created_time = job.get('CreatedOn')
                if created_time and created_time < cutoff_date:
                    logger.info(f"🧹 Cleaning up old job: {job_name}")
                    job_suffix = job_name.replace('glue-health-check-', '')
                    perform_cleanup(job_name, job_suffix, 'full')
    
    except Exception as e:
        logger.error(f"❌ Age-based cleanup failed: {e}")
        raise

# For scheduled cleanup
def lambda_handler_scheduled(event, context):
    """Handler for scheduled cleanup of old resources"""
    
    try:
        logger.info("🕒 Starting scheduled cleanup")
        cleanup_by_age()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'message': 'Scheduled cleanup completed'
            })
        }
    except Exception as e:
        logger.error(f"❌ Scheduled cleanup failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'message': str(e)
            })
        } 