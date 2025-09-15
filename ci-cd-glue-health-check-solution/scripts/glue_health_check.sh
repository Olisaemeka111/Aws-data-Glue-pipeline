#!/bin/bash
# CI/CD Glue Health Check - Main Orchestrator
# This script handles the complete health check workflow for Glue jobs

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Extract CI/CD information
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

# Validate prerequisites
validate_prerequisites() {
    log "🔍 Validating prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install Terraform."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    # Check if we're in a Git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        log_warning "Not in a Git repository. Some features may not work correctly."
    fi
    
    log_success "Prerequisites validation completed"
}

# Upload scripts to S3
upload_scripts() {
    log "📤 Uploading Glue scripts for health check..."
    
    local bucket_name="${SCRIPTS_BUCKET:-glue-health-check-scripts}"
    local script_prefix="health-check/${UNIQUE_ID}"
    
    # Create bucket if it doesn't exist
    if ! aws s3 ls "s3://${bucket_name}" &> /dev/null; then
        log "Creating S3 bucket: ${bucket_name}"
        aws s3 mb "s3://${bucket_name}" --region "${AWS_DEFAULT_REGION:-us-east-1}"
    fi
    
    # Upload health check scripts
    if [ -d "${PROJECT_ROOT}/src/jobs/health_check" ]; then
        aws s3 sync "${PROJECT_ROOT}/src/jobs/health_check/" "s3://${bucket_name}/${script_prefix}/"
        log_success "Scripts uploaded to s3://${bucket_name}/${script_prefix}/"
    else
        log_error "Health check scripts directory not found: ${PROJECT_ROOT}/src/jobs/health_check"
        exit 1
    fi
    
    # Set script location for Terraform
    export TF_VAR_script_location="s3://${bucket_name}/${script_prefix}/data_processing_health_check.py"
}

# Deploy health check infrastructure
deploy_infrastructure() {
    log "🚀 Deploying health check infrastructure..."
    
    cd "${PROJECT_ROOT}/terraform/modules/glue_health_check"
    
    # Initialize Terraform
    terraform init -input=false
    
    # Plan deployment
    terraform plan \
        -var="job_suffix=${UNIQUE_ID}" \
        -var="is_health_check=true" \
        -var="script_location=${TF_VAR_script_location}" \
        -out="health-check-${UNIQUE_ID}.tfplan"
    
    # Apply deployment
    terraform apply -input=false "health-check-${UNIQUE_ID}.tfplan"
    
    # Get job name from output
    HEALTH_CHECK_JOB_NAME=$(terraform output -raw health_check_job_name 2>/dev/null || echo "glue-health-check-${UNIQUE_ID}")
    
    log_success "Infrastructure deployed. Job name: ${HEALTH_CHECK_JOB_NAME}"
}

# Run health check
run_health_check() {
    log "🔍 Executing health check..."
    
    # Run the health check script
    if ! "${SCRIPT_DIR}/run_glue_health_check.sh" "${UNIQUE_ID}"; then
        log_error "Health check failed"
        return 1
    fi
    
    log_success "Health check completed successfully"
    return 0
}

# Cleanup resources
cleanup_resources() {
    log "🧹 Cleaning up temporary resources..."
    
    local exit_code=$?
    
    cd "${PROJECT_ROOT}/terraform/modules/glue_health_check"
    
    # Destroy infrastructure
    if terraform destroy -auto-approve \
        -var="job_suffix=${UNIQUE_ID}" \
        -var="is_health_check=true" \
        -var="script_location=${TF_VAR_script_location:-dummy}"; then
        log_success "Infrastructure cleanup completed"
    else
        log_error "Infrastructure cleanup failed"
    fi
    
    # Clean up S3 scripts
    local bucket_name="${SCRIPTS_BUCKET:-glue-health-check-scripts}"
    local script_prefix="health-check/${UNIQUE_ID}"
    
    if aws s3 rm "s3://${bucket_name}/${script_prefix}/" --recursive &> /dev/null; then
        log_success "S3 scripts cleanup completed"
    else
        log_warning "S3 scripts cleanup failed or no objects to delete"
    fi
    
    # Clean up Terraform plan files
    rm -f "health-check-${UNIQUE_ID}.tfplan"
    
    return $exit_code
}

# Main execution
main() {
    log "🔄 Starting Glue Job Health Check System"
    echo "=================================================="
    
    # Trap to ensure cleanup happens
    trap cleanup_resources EXIT
    
    # Get CI/CD information
    get_ci_info
    
    # Validate prerequisites
    validate_prerequisites
    
    # Upload scripts
    upload_scripts
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Wait a moment for infrastructure to be ready
    log "⏱️ Waiting for infrastructure to be ready..."
    sleep 30
    
    # Run health check
    if run_health_check; then
        log_success "🎉 Health check passed! ✅"
        echo "=================================================="
        echo "✅ BUILD STATUS: PASS"
        echo "✅ Glue job validation successful"
        echo "✅ No compute issues detected"
        echo "=================================================="
        exit 0
    else
        log_error "💥 Health check failed! ❌"
        echo "=================================================="
        echo "❌ BUILD STATUS: FAIL"
        echo "❌ Glue job validation failed"
        echo "❌ Compute issues detected - review logs"
        echo "=================================================="
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
Glue Health Check - CI/CD Orchestrator

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -d, --debug             Enable debug mode
    -b, --bucket BUCKET     Override S3 bucket name for scripts
    -r, --region REGION     Override AWS region

ENVIRONMENT VARIABLES:
    SCRIPTS_BUCKET          S3 bucket for storing scripts
    AWS_DEFAULT_REGION      AWS region for resources
    DRONE_BRANCH           CI/CD branch name
    DRONE_PULL_REQUEST     CI/CD pull request number
    DRONE_BUILD_NUMBER     CI/CD build number

EXAMPLES:
    # Basic usage
    $0
    
    # With custom bucket
    $0 --bucket my-custom-bucket
    
    # With debug mode
    $0 --debug

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
        -b|--bucket)
            SCRIPTS_BUCKET="$2"
            shift 2
            ;;
        -r|--region)
            AWS_DEFAULT_REGION="$2"
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