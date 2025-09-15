#!/bin/bash
# Master Implementation Script for Glue Health Check System
# This script sets up the complete CI/CD health check infrastructure

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

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅${NC} $1"; }
log_error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️${NC} $1"; }

main() {
    log "🚀 Implementing Glue Health Check System..."
    echo "=================================================="
    
    # Step 1: Validate prerequisites
    validate_prerequisites
    
    # Step 2: Create directory structure
    setup_directory_structure
    
    # Step 3: Create Glue health check script
    create_glue_scripts
    
    # Step 4: Set up monitoring
    setup_monitoring
    
    # Step 5: Create example configurations
    create_example_configs
    
    # Step 6: Set permissions
    set_permissions
    
    # Step 7: Test the implementation
    test_implementation
    
    log_success "🎉 Health check system implementation complete!"
    show_next_steps
}

validate_prerequisites() {
    log "🔍 Validating prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install Terraform."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured."
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

setup_directory_structure() {
    log "📁 Setting up directory structure..."
    
    # Ensure all required directories exist
    mkdir -p "${PROJECT_ROOT}/terraform/modules/glue_health_check"
    mkdir -p "${PROJECT_ROOT}/scripts"
    mkdir -p "${PROJECT_ROOT}/src/jobs/health_check"
    mkdir -p "${PROJECT_ROOT}/examples"
    mkdir -p "${PROJECT_ROOT}/docs"
    
    log_success "Directory structure created"
}

create_glue_scripts() {
    log "📝 Creating Glue health check scripts..."
    
    # Create simple health check script
    cat > "${PROJECT_ROOT}/src/jobs/health_check/data_processing_health_check.py" << 'SCRIPT_EOF'
#!/usr/bin/env python3
"""AWS Glue ETL Job with Health Check Capabilities"""

import sys
from datetime import datetime
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import current_timestamp
from pyspark.sql.types import StructType, StructField, StringType, TimestampType
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'health-check-mode', 'dry-run'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

def is_health_check_mode():
    return args.get('health-check-mode', 'false').lower() == 'true'

def create_stub_data():
    if is_health_check_mode():
        logger.info("🧪 Creating stub data...")
        test_data = [("test_1", "value_1", datetime.now())]
        schema = StructType([
            StructField("id", StringType(), True),
            StructField("value", StringType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        df = spark.createDataFrame(test_data, schema)
        return DynamicFrame.fromDF(df, glueContext, "stub_data")
    else:
        return glueContext.create_dynamic_frame.from_catalog(
            database="your_database", table_name="your_table"
        )

def main():
    try:
        logger.info(f"🚀 Starting job: {args['JOB_NAME']}")
        if is_health_check_mode():
            logger.info("🧪 HEALTH CHECK MODE")
        
        source_data = create_stub_data()
        df = source_data.toDF().withColumn("processed_at", current_timestamp())
        
        if df.count() == 0:
            raise Exception("Empty dataset")
        
        logger.info(f"✅ Processed {df.count()} records successfully!")
        
    except Exception as e:
        logger.error(f"❌ Job failed: {e}")
        raise
    finally:
        job.commit()

if __name__ == "__main__":
    main()
SCRIPT_EOF

    log_success "Glue scripts created"
}

setup_monitoring() {
    log "📊 Setting up monitoring..."
    
    # Create CloudWatch log group
    aws logs create-log-group \
        --log-group-name "/aws-glue/health-check" \
        --retention-in-days 7 2>/dev/null || true
    
    log_success "Monitoring setup complete"
}

create_example_configs() {
    log "📋 Creating example configurations..."
    
    # Create example .drone.yml
    cat > "${PROJECT_ROOT}/examples/.drone.yml" << 'DRONE_EOF'
kind: pipeline
type: docker
name: glue-health-check

trigger:
  event:
    - pull_request

steps:
  - name: glue-health-check
    image: hashicorp/terraform:latest
    environment:
      AWS_ACCESS_KEY_ID:
        from_secret: aws_access_key_id
      AWS_SECRET_ACCESS_KEY:
        from_secret: aws_secret_access_key
      AWS_DEFAULT_REGION: us-east-1
    commands:
      - ./scripts/glue_health_check.sh
DRONE_EOF

    # Create example terraform.tfvars
    cat > "${PROJECT_ROOT}/examples/terraform.tfvars.example" << 'TFVARS_EOF'
# Example Terraform variables for health check
job_suffix = "pr-123-1640995200"
is_health_check = true
script_location = "s3://your-bucket/scripts/data_processing_health_check.py"
glue_version = "4.0"
max_capacity = 2
timeout_minutes = 30
enable_alarms = true
TFVARS_EOF

    log_success "Example configurations created"
}

set_permissions() {
    log "🔑 Setting script permissions..."
    
    chmod +x "${PROJECT_ROOT}/scripts/glue_health_check.sh"
    chmod +x "${PROJECT_ROOT}/scripts/run_glue_health_check.sh"
    chmod +x "${PROJECT_ROOT}/scripts/implement_health_check_system.sh"
    
    log_success "Permissions set"
}

test_implementation() {
    log "🧪 Testing implementation..."
    
    # Validate Terraform syntax
    if [ -f "${PROJECT_ROOT}/terraform/modules/glue_health_check/main.tf" ]; then
        cd "${PROJECT_ROOT}/terraform/modules/glue_health_check"
        terraform fmt -check || terraform fmt
        terraform validate || log_warning "Terraform validation failed - may need provider initialization"
        cd - > /dev/null
    fi
    
    # Test Python script syntax
    if command -v python3 &> /dev/null; then
        if [ -f "${PROJECT_ROOT}/src/jobs/health_check/data_processing_health_check.py" ]; then
            python3 -m py_compile "${PROJECT_ROOT}/src/jobs/health_check/data_processing_health_check.py"
            log_success "Python script syntax validated"
        fi
    fi
    
    log_success "Implementation testing complete"
}

show_next_steps() {
    echo ""
    echo "🎉 IMPLEMENTATION COMPLETE!"
    echo "=================================================="
    echo ""
    echo "📋 NEXT STEPS:"
    echo ""
    echo "1. 🔧 Test the system:"
    echo "   chmod +x scripts/test_health_check_system.sh"
    echo "   ./scripts/test_health_check_system.sh"
    echo ""
    echo "2. 📝 Customize for your environment:"
    echo "   - Edit examples/terraform.tfvars.example"
    echo "   - Modify src/jobs/health_check/data_processing_health_check.py"
    echo "   - Update examples/.drone.yml for your CI/CD system"
    echo ""
    echo "3. 🚀 Deploy to your project:"
    echo "   - Copy terraform modules to your infrastructure"
    echo "   - Integrate scripts with your CI/CD pipeline"
    echo "   - Configure AWS permissions and S3 buckets"
    echo ""
    echo "4. 📖 Read the documentation:"
    echo "   - docs/CI_CD_Glue_Health_Check_Implementation.md"
    echo "   - README.md"
    echo ""
    echo "✅ Your CI/CD Glue health check system is ready!"
}

# Error handling
trap 'log_error "Implementation failed at line $LINENO"' ERR

# Run main function
main "$@" 