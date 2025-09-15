#!/bin/bash
# Glue Job Runner and Monitor for Health Checks
# This script starts, monitors, and validates Glue job execution

set -e

# Configuration
UNIQUE_ID=$1
JOB_NAME="glue-health-check-${UNIQUE_ID}"
MAX_WAIT_TIME=1800  # 30 minutes
POLL_INTERVAL=30    # 30 seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

# Validate input
if [ -z "$UNIQUE_ID" ]; then
    log_error "Usage: $0 <unique_id>"
    log_error "Example: $0 pr-123-1640995200"
    exit 1
fi

# Function to format duration
format_duration() {
    local duration=$1
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Function to get job run details
get_job_run_details() {
    local job_name=$1
    local run_id=$2
    
    aws glue get-job-run \
        --job-name "$job_name" \
        --run-id "$run_id" \
        --output json 2>/dev/null || echo "{}"
}

# Function to display job metrics
display_job_metrics() {
    local job_name=$1
    local run_id=$2
    
    log "📊 Retrieving job execution metrics..."
    
    local job_details
    job_details=$(get_job_run_details "$job_name" "$run_id")
    
    if [ "$job_details" != "{}" ]; then
        local execution_time
        local dpu_seconds
        local max_capacity
        local started_on
        local completed_on
        
        execution_time=$(echo "$job_details" | jq -r '.JobRun.ExecutionTime // "N/A"')
        dpu_seconds=$(echo "$job_details" | jq -r '.JobRun.DPUSeconds // "N/A"')
        max_capacity=$(echo "$job_details" | jq -r '.JobRun.MaxCapacity // "N/A"')
        started_on=$(echo "$job_details" | jq -r '.JobRun.StartedOn // "N/A"')
        completed_on=$(echo "$job_details" | jq -r '.JobRun.CompletedOn // "N/A"')
        
        echo "=================================================="
        echo "📊 JOB EXECUTION METRICS"
        echo "=================================================="
        echo "Job Name:       $job_name"
        echo "Run ID:         $run_id"
        echo "Execution Time: $execution_time seconds"
        echo "DPU Seconds:    $dpu_seconds"
        echo "Max Capacity:   $max_capacity DPU"
        echo "Started On:     $started_on"
        echo "Completed On:   $completed_on"
        echo "=================================================="
    fi
}

# Function to get error details
get_error_details() {
    local job_name=$1
    local run_id=$2
    
    log "🔍 Retrieving error details..."
    
    local job_details
    job_details=$(get_job_run_details "$job_name" "$run_id")
    
    if [ "$job_details" != "{}" ]; then
        local error_message
        local logs_link
        
        error_message=$(echo "$job_details" | jq -r '.JobRun.ErrorMessage // "No error message available"')
        logs_link=$(echo "$job_details" | jq -r '.JobRun.LogGroupName // "N/A"')
        
        echo "=================================================="
        echo "❌ ERROR DETAILS"
        echo "=================================================="
        echo "Error Message:"
        echo "$error_message"
        echo ""
        echo "CloudWatch Logs:"
        if [ "$logs_link" != "N/A" ]; then
            echo "Log Group: $logs_link"
            echo "View logs with:"
            echo "aws logs describe-log-streams --log-group-name '$logs_link'"
        else
            echo "No log group information available"
        fi
        echo "=================================================="
    fi
}

# Function to check if job exists
check_job_exists() {
    local job_name=$1
    
    if aws glue get-job --job-name "$job_name" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to start job with retry
start_job_with_retry() {
    local job_name=$1
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        log "🚀 Starting Glue job (attempt $((retry_count + 1))/$max_retries): $job_name"
        
        local job_run_id
        job_run_id=$(aws glue start-job-run \
            --job-name "$job_name" \
            --arguments '{"--health-check-mode":"true","--stub-data-sources":"true","--dry-run":"true"}' \
            --query 'JobRunId' \
            --output text 2>/dev/null)
        
        if [ -n "$job_run_id" ] && [ "$job_run_id" != "None" ]; then
            echo "$job_run_id"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            log_warning "Failed to start job, retrying in 10 seconds..."
            sleep 10
        fi
    done
    
    return 1
}

# Main execution function
main() {
    log "🔄 Starting Glue job health check execution"
    log "Job name: $JOB_NAME"
    log "Max wait time: $(format_duration $MAX_WAIT_TIME)"
    log "Poll interval: ${POLL_INTERVAL}s"
    echo ""
    
    # Check if job exists
    if ! check_job_exists "$JOB_NAME"; then
        log_error "Glue job '$JOB_NAME' does not exist"
        log_error "Make sure the infrastructure deployment completed successfully"
        exit 1
    fi
    
    log_success "Glue job found: $JOB_NAME"
    
    # Start the job
    local job_run_id
    if ! job_run_id=$(start_job_with_retry "$JOB_NAME"); then
        log_error "Failed to start Glue job after multiple attempts"
        exit 1
    fi
    
    log_success "Job started successfully"
    log "📊 Job Run ID: $job_run_id"
    log "⏱️ Monitoring job status..."
    echo ""
    
    # Monitor job status
    local start_time
    start_time=$(date +%s)
    local last_status=""
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        
        # Check for timeout
        if [ $elapsed_time -gt $MAX_WAIT_TIME ]; then
            log_error "⏰ Job timeout after $(format_duration $MAX_WAIT_TIME)"
            log "🛑 Stopping job..."
            
            aws glue batch-stop-job-run \
                --job-name "$JOB_NAME" \
                --job-runs-to-stop "$job_run_id" &> /dev/null || true
            
            log_error "Health check failed due to timeout"
            exit 1
        fi
        
        # Get current job status
        local job_status
        job_status=$(aws glue get-job-run \
            --job-name "$JOB_NAME" \
            --run-id "$job_run_id" \
            --query 'JobRun.JobRunState' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        # Only log status changes to reduce noise
        if [ "$job_status" != "$last_status" ]; then
            log "📈 Job Status: $job_status ($(format_duration $elapsed_time) elapsed)"
            last_status="$job_status"
        fi
        
        case $job_status in
            "SUCCEEDED")
                log_success "🎉 Glue job completed successfully!"
                display_job_metrics "$JOB_NAME" "$job_run_id"
                
                # Validate that the job actually did something
                local execution_time
                execution_time=$(aws glue get-job-run \
                    --job-name "$JOB_NAME" \
                    --run-id "$job_run_id" \
                    --query 'JobRun.ExecutionTime' \
                    --output text 2>/dev/null || echo "0")
                
                if [ "$execution_time" -gt 10 ]; then
                    log_success "✅ Health check validation: Job ran for ${execution_time}s - PASS"
                else
                    log_warning "⚠️ Health check validation: Job ran for only ${execution_time}s - may need investigation"
                fi
                
                exit 0
                ;;
            "FAILED"|"ERROR"|"TIMEOUT")
                log_error "💥 Glue job failed with status: $job_status"
                get_error_details "$JOB_NAME" "$job_run_id"
                log_error "❌ Health check validation: FAIL"
                exit 1
                ;;
            "STOPPED"|"STOPPING")
                log_error "🛑 Glue job was stopped"
                log_error "❌ Health check validation: FAIL"
                exit 1
                ;;
            "RUNNING"|"STARTING")
                # Show progress indicator every 5 polls (2.5 minutes)
                if [ $((elapsed_time % 150)) -eq 0 ] && [ $elapsed_time -gt 0 ]; then
                    log "⏳ Still running... $(format_duration $elapsed_time) elapsed"
                fi
                sleep $POLL_INTERVAL
                ;;
            "UNKNOWN")
                log_warning "❓ Could not retrieve job status - retrying..."
                sleep $POLL_INTERVAL
                ;;
            *)
                log_warning "❓ Unknown job status: $job_status - continuing to monitor..."
                sleep $POLL_INTERVAL
                ;;
        esac
    done
}

# Help function
show_help() {
    cat << EOF
Glue Job Health Check Runner

USAGE:
    $0 <unique_id>

DESCRIPTION:
    Starts and monitors a Glue job for health check validation.
    The job runs with stubbed data and validates compute logic.

PARAMETERS:
    unique_id    Unique identifier for the health check job

EXAMPLES:
    $0 pr-123-1640995200
    $0 local-1640995200

EXIT CODES:
    0    Health check passed
    1    Health check failed or error occurred

EOF
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        log_error "Missing required parameter: unique_id"
        show_help
        exit 1
        ;;
esac

# Check if jq is available (optional but helpful)
if ! command -v jq &> /dev/null; then
    log_warning "jq not found - JSON output will be raw"
fi

# Run main function
main 