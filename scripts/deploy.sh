#!/bin/bash

# AWS Glue ETL Pipeline Deployment Script
# Enhanced version with comprehensive error handling and validation

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/glue-etl-deploy-$(date +%Y%m%d-%H%M%S).log"
TERRAFORM_PLAN_FILE="/tmp/terraform-plan-$(date +%Y%m%d-%H%M%S).tfplan"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_warn() {
    log "WARN" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

# Progress tracking
show_progress() {
    local step=$1
    local total=$2
    local description=$3
    echo -e "\n${BLUE}[Step $step/$total] $description${NC}\n"
}

# Error handling
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Deployment failed with exit code $exit_code"
        log_error "Check the log file for details: $LOG_FILE"
        
        # Cleanup temporary files
        [[ -f "$TERRAFORM_PLAN_FILE" ]] && rm -f "$TERRAFORM_PLAN_FILE"
        
        if [[ "${ROLLBACK_ON_FAILURE:-false}" == "true" ]]; then
            log_warn "Initiating rollback..."
            perform_rollback
        fi
    else
        log_success "Deployment completed successfully!"
        # Cleanup temporary files on success
        [[ -f "$TERRAFORM_PLAN_FILE" ]] && rm -f "$TERRAFORM_PLAN_FILE"
    fi
}

trap cleanup EXIT

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Enhanced AWS Glue ETL Pipeline Deployment Script

OPTIONS:
    -e, --environment ENVIRONMENT    Target environment (dev, staging, prod)
    -r, --region REGION             AWS region to deploy to
    -p, --plan-only                 Only generate and show Terraform plan
    -a, --auto-approve              Auto-approve Terraform apply (skip confirmation)
    -v, --validate-only             Only validate configuration without deploying
    -u, --upload-scripts            Upload job scripts to S3 before deployment
    -b, --backup                    Create backup before deployment
    -R, --rollback-on-failure       Automatically rollback on deployment failure
    -f, --force                     Force deployment even if validation warnings exist
    -h, --help                      Show this help message

EXAMPLES:
    $0 -e dev -r us-east-1                    # Deploy to dev environment
    $0 -e prod -r us-east-1 -u -b             # Deploy to prod with script upload and backup
    $0 -e staging -r us-west-2 -p             # Generate plan only for staging
    $0 -e prod -r us-east-1 -v                # Validate prod configuration only

ENVIRONMENT VARIABLES:
    AWS_PROFILE                     AWS CLI profile to use
    TF_VAR_*                       Terraform variables (e.g., TF_VAR_project_name)
    ROLLBACK_ON_FAILURE            Enable automatic rollback (true/false)
    SKIP_VALIDATION                Skip pre-deployment validation (true/false)
    
EOF
}

# Default values
ENVIRONMENT=""
AWS_REGION=""
PLAN_ONLY=false
AUTO_APPROVE=false
VALIDATE_ONLY=false
UPLOAD_SCRIPTS=false
CREATE_BACKUP=false
ROLLBACK_ON_FAILURE=false
FORCE_DEPLOY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -p|--plan-only)
            PLAN_ONLY=true
            shift
            ;;
        -a|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -v|--validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -u|--upload-scripts)
            UPLOAD_SCRIPTS=true
            shift
            ;;
        -b|--backup)
            CREATE_BACKUP=true
            shift
            ;;
        -R|--rollback-on-failure)
            ROLLBACK_ON_FAILURE=true
            shift
            ;;
        -f|--force)
            FORCE_DEPLOY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validation functions
validate_environment() {
    if [[ -z "$ENVIRONMENT" ]]; then
        log_error "Environment is required. Use -e or --environment"
        usage
        exit 1
    fi
    
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be one of: dev, staging, prod"
        exit 1
    fi
    
    log_info "Environment: $ENVIRONMENT"
}

validate_aws_region() {
    if [[ -z "$AWS_REGION" ]]; then
        log_error "AWS region is required. Use -r or --region"
        usage
        exit 1
    fi
    
    log_info "AWS Region: $AWS_REGION"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if required tools are installed
    local tools=("aws" "terraform" "jq" "python3")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
        log_info "✓ $tool is available"
    done
    
    # Check Terraform version
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $tf_version"
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured or credentials are invalid"
        log_error "Please run 'aws configure' or set AWS_PROFILE environment variable"
        exit 1
    fi
    
    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    local aws_user=$(aws sts get-caller-identity --query Arn --output text)
    log_info "AWS Account: $aws_account"
    log_info "AWS User/Role: $aws_user"
    
    # Validate AWS region
    if ! aws ec2 describe-regions --region-names "$AWS_REGION" &> /dev/null; then
        log_error "Invalid AWS region: $AWS_REGION"
        exit 1
    fi
}

validate_terraform_files() {
    log_info "Validating Terraform configuration..."
    
    local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    
    if [[ ! -d "$terraform_dir" ]]; then
        log_error "Terraform environment directory not found: $terraform_dir"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    if ! terraform init -backend=true >> "$LOG_FILE" 2>&1; then
        log_error "Terraform initialization failed"
        exit 1
    fi
    
    # Validate Terraform configuration
    log_info "Validating Terraform configuration..."
    if ! terraform validate >> "$LOG_FILE" 2>&1; then
        log_error "Terraform validation failed"
        exit 1
    fi
    
    log_success "Terraform configuration is valid"
}

validate_glue_scripts() {
    log_info "Validating Glue job scripts..."
    
    local scripts_dir="$PROJECT_ROOT/src/jobs"
    local scripts=("data_ingestion.py" "data_processing.py" "data_quality.py")
    
    for script in "${scripts[@]}"; do
        local script_path="$scripts_dir/$script"
        if [[ ! -f "$script_path" ]]; then
            log_error "Required Glue script not found: $script_path"
            exit 1
        fi
        
        # Basic Python syntax validation
        if ! python3 -m py_compile "$script_path" >> "$LOG_FILE" 2>&1; then
            log_error "Python syntax error in $script"
            exit 1
        fi
        
        log_info "✓ $script is valid"
    done
    
    # Validate utility modules
    local utils_dir="$PROJECT_ROOT/src/utils"
    if [[ -f "$utils_dir/glue_utils.py" ]]; then
        if ! python3 -m py_compile "$utils_dir/glue_utils.py" >> "$LOG_FILE" 2>&1; then
            log_error "Python syntax error in glue_utils.py"
            exit 1
        fi
        log_info "✓ glue_utils.py is valid"
    fi
}

upload_glue_scripts() {
    log_info "Uploading Glue job scripts to S3..."
    
    # Get the scripts bucket name from Terraform output or variables
    local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    cd "$terraform_dir"
    
    # Try to get bucket name from Terraform state
    local scripts_bucket=""
    if terraform show -json 2>/dev/null | jq -r '.values.outputs.scripts_bucket_name.value' &> /dev/null; then
        scripts_bucket=$(terraform show -json | jq -r '.values.outputs.scripts_bucket_name.value')
    fi
    
    if [[ -z "$scripts_bucket" || "$scripts_bucket" == "null" ]]; then
        # Fallback to variable-based naming
        local project_name="${TF_VAR_project_name:-glue-etl-pipeline}"
        scripts_bucket="${project_name}-${ENVIRONMENT}-scripts"
    fi
    
    log_info "Scripts bucket: $scripts_bucket"
    
    # Check if bucket exists
    if ! aws s3 ls "s3://$scripts_bucket" &> /dev/null; then
        log_warn "Scripts bucket does not exist yet. It will be created during Terraform deployment."
        return 0
    fi
    
    # Upload job scripts
    local scripts_dir="$PROJECT_ROOT/src"
    if ! aws s3 sync "$scripts_dir" "s3://$scripts_bucket/" --delete --exclude "*.pyc" --exclude "__pycache__/*" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to upload scripts to S3"
        exit 1
    fi
    
    log_success "Scripts uploaded successfully to s3://$scripts_bucket/"
}

create_backup() {
    log_info "Creating backup of current infrastructure state..."
    
    local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    local backup_dir="$PROJECT_ROOT/backups/${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
    
    mkdir -p "$backup_dir"
    
    cd "$terraform_dir"
    
    # Backup Terraform state
    if [[ -f "terraform.tfstate" ]]; then
        cp "terraform.tfstate" "$backup_dir/"
        log_info "Terraform state backed up"
    fi
    
    # Backup Terraform plan if it exists
    if terraform show -json &> /dev/null; then
        terraform show -json > "$backup_dir/current-state.json"
        log_info "Current infrastructure state backed up"
    fi
    
    # Export current resource information
    {
        echo "# Backup created on $(date)"
        echo "# Environment: $ENVIRONMENT"
        echo "# Region: $AWS_REGION"
        echo ""
        
        # Try to get key resource information
        aws sts get-caller-identity 2>/dev/null || echo "Could not get caller identity"
        echo ""
        
        # List S3 buckets with project prefix
        local project_name="${TF_VAR_project_name:-glue-etl-pipeline}"
        aws s3 ls | grep "$project_name-$ENVIRONMENT" || echo "No project S3 buckets found"
        
    } > "$backup_dir/backup-info.txt"
    
    log_success "Backup created in: $backup_dir"
    echo "$backup_dir" > "/tmp/last-backup-path"
}

perform_rollback() {
    log_warn "Performing rollback..."
    
    local backup_path=""
    if [[ -f "/tmp/last-backup-path" ]]; then
        backup_path=$(cat "/tmp/last-backup-path")
    fi
    
    if [[ -n "$backup_path" && -d "$backup_path" ]]; then
        log_info "Restoring from backup: $backup_path"
        
        local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
        cd "$terraform_dir"
        
        if [[ -f "$backup_path/terraform.tfstate" ]]; then
            cp "$backup_path/terraform.tfstate" "./terraform.tfstate"
            log_info "Terraform state restored"
            
            # Refresh and show current state
            terraform refresh >> "$LOG_FILE" 2>&1 || log_warn "Could not refresh Terraform state"
        fi
        
        log_success "Rollback completed"
    else
        log_warn "No backup found for rollback"
    fi
}

generate_terraform_plan() {
    log_info "Generating Terraform execution plan..."
    
    local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    cd "$terraform_dir"
    
    # Set Terraform variables
    export TF_VAR_aws_region="$AWS_REGION"
    export TF_VAR_environment="$ENVIRONMENT"
    
    # Generate plan
    if ! terraform plan -out="$TERRAFORM_PLAN_FILE" -detailed-exitcode >> "$LOG_FILE" 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            log_error "Terraform plan failed"
            exit 1
        elif [[ $exit_code -eq 2 ]]; then
            log_info "Terraform plan shows changes to be made"
        fi
    else
        log_info "No changes detected in Terraform plan"
    fi
    
    # Show plan summary
    log_info "Terraform plan summary:"
    terraform show -no-color "$TERRAFORM_PLAN_FILE" | head -n 20 | tee -a "$LOG_FILE"
    
    # Show resource changes count
    local changes_count=$(terraform show -json "$TERRAFORM_PLAN_FILE" | jq '.resource_changes | length')
    log_info "Number of resources to be changed: $changes_count"
    
    if [[ $changes_count -gt 0 ]]; then
        log_info "Resource changes summary:"
        terraform show -json "$TERRAFORM_PLAN_FILE" | jq -r '.resource_changes[] | "\(.change.actions[0]): \(.address)"' | tee -a "$LOG_FILE"
    fi
}

apply_terraform() {
    log_info "Applying Terraform configuration..."
    
    local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    cd "$terraform_dir"
    
    local apply_args=()
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        apply_args+=("-auto-approve")
    fi
    
    if [[ -f "$TERRAFORM_PLAN_FILE" ]]; then
        apply_args+=("$TERRAFORM_PLAN_FILE")
    fi
    
    if ! terraform apply "${apply_args[@]}" >> "$LOG_FILE" 2>&1; then
        log_error "Terraform apply failed"
        exit 1
    fi
    
    log_success "Terraform apply completed successfully"
}

validate_deployment() {
    log_info "Validating deployment..."
    
    local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    cd "$terraform_dir"
    
    # Check if key resources were created
    local validation_errors=0
    
    # Get outputs
    local outputs
    if ! outputs=$(terraform output -json 2>/dev/null); then
        log_warn "Could not get Terraform outputs"
        return 0
    fi
    
    # Validate S3 buckets
    local buckets=("raw_bucket_name" "processed_bucket_name" "curated_bucket_name" "scripts_bucket_name")
    for bucket_output in "${buckets[@]}"; do
        local bucket_name
        bucket_name=$(echo "$outputs" | jq -r ".$bucket_output.value // empty")
        
        if [[ -n "$bucket_name" && "$bucket_name" != "null" ]]; then
            if aws s3 ls "s3://$bucket_name" &> /dev/null; then
                log_info "✓ S3 bucket verified: $bucket_name"
            else
                log_error "✗ S3 bucket not accessible: $bucket_name"
                ((validation_errors++))
            fi
        fi
    done
    
    # Validate Glue jobs
    local project_name="${TF_VAR_project_name:-glue-etl-pipeline}"
    local jobs=("data-ingestion" "data-processing" "data-quality")
    for job in "${jobs[@]}"; do
        local job_name="${project_name}-${ENVIRONMENT}-${job}"
        if aws glue get-job --job-name "$job_name" &> /dev/null; then
            log_info "✓ Glue job verified: $job_name"
        else
            log_error "✗ Glue job not found: $job_name"
            ((validation_errors++))
        fi
    done
    
    # Validate DynamoDB tables
    local tables=("job-state" "job-bookmarks")
    for table in "${tables[@]}"; do
        local table_name="${project_name}-${ENVIRONMENT}-${table}"
        if aws dynamodb describe-table --table-name "$table_name" &> /dev/null; then
            log_info "✓ DynamoDB table verified: $table_name"
        else
            log_error "✗ DynamoDB table not found: $table_name"
            ((validation_errors++))
        fi
    done
    
    if [[ $validation_errors -gt 0 ]]; then
        log_error "Deployment validation failed with $validation_errors errors"
        if [[ "$FORCE_DEPLOY" != "true" ]]; then
            exit 1
        else
            log_warn "Continuing despite validation errors due to --force flag"
        fi
    else
        log_success "Deployment validation passed"
    fi
}

post_deployment_steps() {
    log_info "Performing post-deployment steps..."
    
    # Upload scripts if not done earlier
    if [[ "$UPLOAD_SCRIPTS" == "true" ]]; then
        upload_glue_scripts
    fi
    
    # Output useful information
    local terraform_dir="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    cd "$terraform_dir"
    
    log_info "Deployment Summary:"
    terraform output 2>/dev/null | tee -a "$LOG_FILE" || log_warn "Could not get Terraform outputs"
    
    log_info "Log file location: $LOG_FILE"
}

# Main execution
main() {
    log_info "Starting AWS Glue ETL Pipeline deployment"
    log_info "Script version: 2.0"
    log_info "Log file: $LOG_FILE"
    
    show_progress 1 8 "Validating input parameters"
    validate_environment
    validate_aws_region
    
    show_progress 2 8 "Checking prerequisites"
    check_prerequisites
    
    if [[ "${SKIP_VALIDATION:-false}" != "true" ]]; then
        show_progress 3 8 "Validating Terraform configuration"
        validate_terraform_files
        
        show_progress 4 8 "Validating Glue scripts"
        validate_glue_scripts
    else
        log_warn "Skipping validation due to SKIP_VALIDATION environment variable"
    fi
    
    if [[ "$VALIDATE_ONLY" == "true" ]]; then
        log_success "Validation completed successfully"
        exit 0
    fi
    
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        show_progress 5 8 "Creating backup"
        create_backup
    fi
    
    if [[ "$UPLOAD_SCRIPTS" == "true" ]]; then
        show_progress 6 8 "Uploading Glue scripts"
        upload_glue_scripts
    fi
    
    show_progress 7 8 "Generating Terraform plan"
    generate_terraform_plan
    
    if [[ "$PLAN_ONLY" == "true" ]]; then
        log_success "Plan generation completed"
        exit 0
    fi
    
    show_progress 8 8 "Applying Terraform configuration"
    apply_terraform
    
    log_info "Validating deployment"
    validate_deployment
    
    log_info "Performing post-deployment steps"
    post_deployment_steps
    
    log_success "Deployment completed successfully!"
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $AWS_REGION"
    log_info "Log file: $LOG_FILE"
}

# Execute main function
main "$@"
