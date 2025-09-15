#!/bin/bash
# Enhanced CI/CD Glue Health Check with Lambda Orchestration
# This script uses Lambda functions for better integration with CI/CD systems

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"; }
log_error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"; }

# Configuration variables
USE_LAMBDA=${USE_LAMBDA:-true}
LAMBDA_TRIGGER_FUNCTION=""
LAMBDA_MONITOR_FUNCTION=""
LAMBDA_CLEANUP_FUNCTION=""

# Main execution
main() {
    log "🔄 Starting Enhanced Glue Health Check with Lambda"
    echo "=================================================="
    
    # Get CI/CD information
    get_ci_info
    
    # Validate prerequisites
    validate_prerequisites
    
    # Check Lambda deployment preference
    if [ "$USE_LAMBDA" = "true" ]; then
        log "🔧 Using Lambda-based orchestration"
        run_lambda_workflow
    else
        log "🔧 Using direct Terraform orchestration"
        run_terraform_workflow
    fi
}

get_ci_info() {
    # Drone CI variables
    BRANCH_NAME=${DRONE_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")}
    PR_NUMBER=${DRONE_PULL_REQUEST:-"local-$(date +%s)"}
    BUILD_NUMBER=${DRONE_BUILD_NUMBER:-"local"}
    
    # Generate unique identifier
    UNIQUE_ID="${PR_NUMBER}-$(date +%s)"
    
    log "CI/CD Information:"
    echo "  Branch: $BRANCH_NAME"
    echo "  PR Number: $PR_NUMBER"
    echo "  Build Number: $BUILD_NUMBER"
    echo "  Unique ID: $UNIQUE_ID"
}

validate_prerequisites() {
    log "🔍 Validating prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    # If using Lambda, check for function names
    if [ "$USE_LAMBDA" = "true" ]; then
        get_lambda_function_names
        validate_lambda_functions
    fi
    
    log_success "Prerequisites validation completed"
}

get_lambda_function_names() {
    log "🔍 Discovering Lambda function names..."
    
    # Try to get function names from environment variables first
    LAMBDA_TRIGGER_FUNCTION=${LAMBDA_TRIGGER_FUNCTION:-$HEALTH_CHECK_TRIGGER_FUNCTION}
    LAMBDA_MONITOR_FUNCTION=${LAMBDA_MONITOR_FUNCTION:-$HEALTH_CHECK_MONITOR_FUNCTION}
    LAMBDA_CLEANUP_FUNCTION=${LAMBDA_CLEANUP_FUNCTION:-$HEALTH_CHECK_CLEANUP_FUNCTION}
    
    # If not set, try to discover from AWS
    if [ -z "$LAMBDA_TRIGGER_FUNCTION" ]; then
        log "🔍 Auto-discovering Lambda functions..."
        
        # Get functions with health-check in the name
        LAMBDA_TRIGGER_FUNCTION=$(aws lambda list-functions \
            --query "Functions[?contains(FunctionName, 'health-check-trigger')].FunctionName" \
            --output text | head -1)
        
        LAMBDA_MONITOR_FUNCTION=$(aws lambda list-functions \
            --query "Functions[?contains(FunctionName, 'health-check-monitor')].FunctionName" \
            --output text | head -1)
        
        LAMBDA_CLEANUP_FUNCTION=$(aws lambda list-functions \
            --query "Functions[?contains(FunctionName, 'health-check-cleanup')].FunctionName" \
            --output text | head -1)
    fi
    
    log "Lambda Functions:"
    echo "  Trigger: ${LAMBDA_TRIGGER_FUNCTION:-'Not found'}"
    echo "  Monitor: ${LAMBDA_MONITOR_FUNCTION:-'Not found'}"
    echo "  Cleanup: ${LAMBDA_CLEANUP_FUNCTION:-'Not found'}"
}

validate_lambda_functions() {
    log "🔍 Validating Lambda functions..."
    
    if [ -z "$LAMBDA_TRIGGER_FUNCTION" ]; then
        log_error "Health check trigger Lambda function not found"
        log_error "Set LAMBDA_TRIGGER_FUNCTION environment variable or deploy Lambda functions"
        exit 1
    fi
    
    # Test if function exists
    if ! aws lambda get-function --function-name "$LAMBDA_TRIGGER_FUNCTION" &> /dev/null; then
        log_error "Lambda function not accessible: $LAMBDA_TRIGGER_FUNCTION"
        exit 1
    fi
    
    log_success "Lambda functions validated"
}

run_lambda_workflow() {
    log "🚀 Starting Lambda-based health check workflow"
    
    # 1. Trigger health check via Lambda
    trigger_health_check_lambda
    
    # 2. Monitor job status
    monitor_job_status_lambda
    
    # 3. Handle results
    handle_workflow_results
}

trigger_health_check_lambda() {
    log "📤 Triggering health check via Lambda..."
    
    # Prepare payload
    local payload=$(cat << EOF
{
    "pr_number": "$PR_NUMBER",
    "branch": "$BRANCH_NAME",
    "script_location": "${SCRIPT_LOCATION:-s3://your-bucket/scripts/health_check_script.py}",
    "job_arguments": {
        "--enable-debug": "true"
    },
    "build_info": {
        "build_number": "$BUILD_NUMBER",
        "trigger_source": "ci-cd"
    }
}
EOF
)
    
    # Invoke Lambda function
    log "🔄 Invoking Lambda function: $LAMBDA_TRIGGER_FUNCTION"
    
    local response_file="/tmp/lambda_trigger_response.json"
    
    aws lambda invoke \
        --function-name "$LAMBDA_TRIGGER_FUNCTION" \
        --payload "$payload" \
        "$response_file" > /dev/null
    
    # Parse response
    if [ -f "$response_file" ]; then
        local status_code=$(jq -r '.statusCode' "$response_file" 2>/dev/null || echo "unknown")
        local response_body=$(jq -r '.body' "$response_file" 2>/dev/null || cat "$response_file")
        
        if [ "$status_code" = "200" ]; then
            # Extract job information
            HEALTH_CHECK_JOB_NAME=$(echo "$response_body" | jq -r '.job_name' 2>/dev/null || echo "")
            HEALTH_CHECK_JOB_RUN_ID=$(echo "$response_body" | jq -r '.job_run_id' 2>/dev/null || echo "")
            
            log_success "Health check triggered successfully"
            log "Job Name: $HEALTH_CHECK_JOB_NAME"
            log "Job Run ID: $HEALTH_CHECK_JOB_RUN_ID"
        else
            log_error "Lambda function returned error: $status_code"
            log_error "Response: $response_body"
            exit 1
        fi
        
        rm -f "$response_file"
    else
        log_error "No response file created"
        exit 1
    fi
}

monitor_job_status_lambda() {
    log "👀 Monitoring job status via Lambda..."
    
    if [ -z "$HEALTH_CHECK_JOB_NAME" ]; then
        log_error "No job name available for monitoring"
        exit 1
    fi
    
    local max_wait_time=1800  # 30 minutes
    local poll_interval=30    # 30 seconds
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        
        # Check for timeout
        if [ $elapsed_time -gt $max_wait_time ]; then
            log_error "⏰ Health check timeout after $((max_wait_time / 60)) minutes"
            # Trigger cleanup
            trigger_cleanup_lambda
            exit 1
        fi
        
        # Monitor via Lambda if available, otherwise direct AWS API
        if [ -n "$LAMBDA_MONITOR_FUNCTION" ]; then
            check_status_via_lambda
        else
            check_status_direct
        fi
        
        # Check result
        case "$JOB_STATUS" in
            "SUCCEEDED"|"PASS")
                log_success "🎉 Health check completed successfully!"
                return 0
                ;;
            "FAILED"|"ERROR"|"TIMEOUT"|"FAIL")
                log_error "💥 Health check failed with status: $JOB_STATUS"
                return 1
                ;;
            "RUNNING"|"STARTING")
                log "⏳ Health check still running... (${elapsed_time}s elapsed)"
                sleep $poll_interval
                ;;
            *)
                log_warning "❓ Unknown status: $JOB_STATUS - continuing to monitor..."
                sleep $poll_interval
                ;;
        esac
    done
}

check_status_via_lambda() {
    local payload='{"job_name":"'$HEALTH_CHECK_JOB_NAME'","job_run_id":"'$HEALTH_CHECK_JOB_RUN_ID'"}'
    local response_file="/tmp/lambda_monitor_response.json"
    
    aws lambda invoke \
        --function-name "$LAMBDA_MONITOR_FUNCTION" \
        --payload "$payload" \
        "$response_file" > /dev/null
    
    if [ -f "$response_file" ]; then
        local response_body=$(jq -r '.body' "$response_file" 2>/dev/null || cat "$response_file")
        JOB_STATUS=$(echo "$response_body" | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
        rm -f "$response_file"
    else
        JOB_STATUS="UNKNOWN"
    fi
}

check_status_direct() {
    JOB_STATUS=$(aws glue get-job-run \
        --job-name "$HEALTH_CHECK_JOB_NAME" \
        --run-id "$HEALTH_CHECK_JOB_RUN_ID" \
        --query 'JobRun.JobRunState' \
        --output text 2>/dev/null || echo "UNKNOWN")
}

trigger_cleanup_lambda() {
    log "🧹 Triggering cleanup via Lambda..."
    
    if [ -z "$LAMBDA_CLEANUP_FUNCTION" ]; then
        log_warning "No cleanup Lambda function configured"
        return
    fi
    
    local payload='{"job_name":"'$HEALTH_CHECK_JOB_NAME'","cleanup_type":"full"}'
    
    aws lambda invoke \
        --function-name "$LAMBDA_CLEANUP_FUNCTION" \
        --invocation-type Event \
        --payload "$payload" \
        /dev/null > /dev/null
    
    log "🧹 Cleanup triggered asynchronously"
}

handle_workflow_results() {
    if [ "$JOB_STATUS" = "SUCCEEDED" ] || [ "$JOB_STATUS" = "PASS" ]; then
        log_success "🎉 Health check workflow completed successfully!"
        echo "=================================================="
        echo "✅ BUILD STATUS: PASS"
        echo "✅ Glue job validation successful"
        echo "✅ No compute issues detected"
        echo "=================================================="
        
        # Trigger cleanup
        trigger_cleanup_lambda
        exit 0
    else
        log_error "💥 Health check workflow failed!"
        echo "=================================================="
        echo "❌ BUILD STATUS: FAIL"
        echo "❌ Glue job validation failed"
        echo "❌ Compute issues detected - review logs"
        echo "=================================================="
        
        # Trigger cleanup
        trigger_cleanup_lambda
        exit 1
    fi
}

run_terraform_workflow() {
    log "🔧 Falling back to Terraform-based workflow"
    
    # Call the original script
    "${SCRIPT_DIR}/glue_health_check.sh" "$@"
}

# Help function
show_help() {
    cat << EOF
Enhanced Glue Health Check with Lambda Integration

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -d, --debug             Enable debug mode
    --use-terraform         Force use of Terraform workflow instead of Lambda
    --trigger-function NAME Override Lambda trigger function name
    --monitor-function NAME Override Lambda monitor function name
    --cleanup-function NAME Override Lambda cleanup function name

ENVIRONMENT VARIABLES:
    USE_LAMBDA                    Use Lambda workflow (default: true)
    LAMBDA_TRIGGER_FUNCTION       Name of trigger Lambda function
    LAMBDA_MONITOR_FUNCTION       Name of monitor Lambda function  
    LAMBDA_CLEANUP_FUNCTION       Name of cleanup Lambda function
    SCRIPT_LOCATION              S3 location of Glue script to test
    DRONE_BRANCH                 CI/CD branch name
    DRONE_PULL_REQUEST           CI/CD pull request number
    DRONE_BUILD_NUMBER           CI/CD build number

EXAMPLES:
    # Use Lambda workflow (default)
    $0
    
    # Force Terraform workflow
    $0 --use-terraform
    
    # Override Lambda function names
    $0 --trigger-function my-trigger-function

WORKFLOW:
    1. 🔄 Trigger health check via Lambda function
    2. 👀 Monitor job status with polling
    3. ✅/❌ Report results to CI/CD system
    4. 🧹 Clean up temporary resources

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--debug)
            set -x
            shift
            ;;
        --use-terraform)
            USE_LAMBDA=false
            shift
            ;;
        --trigger-function)
            LAMBDA_TRIGGER_FUNCTION="$2"
            shift 2
            ;;
        --monitor-function)
            LAMBDA_MONITOR_FUNCTION="$2"
            shift 2
            ;;
        --cleanup-function)
            LAMBDA_CLEANUP_FUNCTION="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@" 