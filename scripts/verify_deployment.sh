#!/bin/bash

# AWS Glue ETL Pipeline - Deployment Verification Script
# This script verifies that all infrastructure components were deployed successfully

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="dev"
PROJECT_NAME="glue-etl-pipeline"
REGION="us-east-1"

echo -e "${BLUE}=== AWS Glue ETL Pipeline Deployment Verification ===${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}Region: ${REGION}${NC}"
echo -e "${BLUE}Project: ${PROJECT_NAME}${NC}"
echo ""

# Function to check resource existence
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local check_command=$3
    
    echo -n "Checking ${resource_type}: ${resource_name}... "
    
    if eval $check_command >/dev/null 2>&1; then
        echo -e "${GREEN}✓ EXISTS${NC}"
        return 0
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        return 1
    fi
}

# Initialize counters
total_checks=0
passed_checks=0

echo -e "${YELLOW}=== 1. VPC & Networking Resources ===${NC}"

# Check VPC
total_checks=$((total_checks + 1))
if check_resource "VPC" "${PROJECT_NAME}-${ENVIRONMENT}-vpc" \
   "aws ec2 describe-vpcs --filters 'Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-vpc' --query 'Vpcs[0].VpcId' --output text --region ${REGION} | grep -v None"; then
    passed_checks=$((passed_checks + 1))
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-vpc" --query 'Vpcs[0].VpcId' --output text --region ${REGION})
    echo "  VPC ID: ${VPC_ID}"
fi

# Check Subnets
for subnet_type in public private; do
    for i in 1 2 3; do
        total_checks=$((total_checks + 1))
        if check_resource "Subnet" "${PROJECT_NAME}-${ENVIRONMENT}-${subnet_type}-subnet-${i}" \
           "aws ec2 describe-subnets --filters 'Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-${subnet_type}-subnet-${i}' --query 'Subnets[0].SubnetId' --output text --region ${REGION} | grep -v None"; then
            passed_checks=$((passed_checks + 1))
        fi
    done
done

echo ""
echo -e "${YELLOW}=== 2. S3 Storage Resources ===${NC}"

# Check S3 Buckets
for bucket_type in raw-data processed-data curated-data scripts temp; do
    bucket_name="${PROJECT_NAME}-${ENVIRONMENT}-${bucket_type}"
    total_checks=$((total_checks + 1))
    if check_resource "S3 Bucket" "${bucket_name}" \
       "aws s3api head-bucket --bucket ${bucket_name} --region ${REGION}"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""
echo -e "${YELLOW}=== 3. DynamoDB Tables ===${NC}"

# Check DynamoDB Tables
for table_type in job-bookmarks metadata; do
    table_name="${PROJECT_NAME}-${ENVIRONMENT}-${table_type}"
    total_checks=$((total_checks + 1))
    if check_resource "DynamoDB Table" "${table_name}" \
       "aws dynamodb describe-table --table-name ${table_name} --region ${REGION}"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""
echo -e "${YELLOW}=== 4. AWS Glue Resources ===${NC}"

# Check Glue Database
database_name="${PROJECT_NAME}_${ENVIRONMENT}_catalog"
total_checks=$((total_checks + 1))
if check_resource "Glue Database" "${database_name}" \
   "aws glue get-database --name ${database_name} --region ${REGION}"; then
    passed_checks=$((passed_checks + 1))
fi

# Check Glue Jobs
for job_type in data-ingestion data-processing data-quality; do
    job_name="${PROJECT_NAME}-${ENVIRONMENT}-${job_type}"
    total_checks=$((total_checks + 1))
    if check_resource "Glue Job" "${job_name}" \
       "aws glue get-job --job-name ${job_name} --region ${REGION}"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check Glue Crawlers
for crawler_type in raw-data processed-data curated-data; do
    crawler_name="${PROJECT_NAME}-${ENVIRONMENT}-${crawler_type}-crawler"
    total_checks=$((total_checks + 1))
    if check_resource "Glue Crawler" "${crawler_name}" \
       "aws glue get-crawler --name ${crawler_name} --region ${REGION}"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check Glue Workflow
workflow_name="${PROJECT_NAME}-${ENVIRONMENT}-etl-workflow"
total_checks=$((total_checks + 1))
if check_resource "Glue Workflow" "${workflow_name}" \
   "aws glue get-workflow --name ${workflow_name} --region ${REGION}"; then
    passed_checks=$((passed_checks + 1))
fi

echo ""
echo -e "${YELLOW}=== 5. Lambda Functions ===${NC}"

# Check Lambda Function
lambda_name="${PROJECT_NAME}-${ENVIRONMENT}-data-trigger"
total_checks=$((total_checks + 1))
if check_resource "Lambda Function" "${lambda_name}" \
   "aws lambda get-function --function-name ${lambda_name} --region ${REGION}"; then
    passed_checks=$((passed_checks + 1))
fi

echo ""
echo -e "${YELLOW}=== 6. SNS Topics ===${NC}"

# Check SNS Topics
for topic_type in security-alerts job-notifications; do
    topic_name="${PROJECT_NAME}-${ENVIRONMENT}-${topic_type}"
    total_checks=$((total_checks + 1))
    if check_resource "SNS Topic" "${topic_name}" \
       "aws sns list-topics --region ${REGION} --query 'Topics[?contains(TopicArn, \`${topic_name}\`)].TopicArn' --output text | grep -v ''"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""
echo -e "${YELLOW}=== 7. IAM Roles ===${NC}"

# Check IAM Roles
for role_type in glue-service glue-crawler data-trigger; do
    role_name="${PROJECT_NAME}-${ENVIRONMENT}-${role_type}-role"
    total_checks=$((total_checks + 1))
    if check_resource "IAM Role" "${role_name}" \
       "aws iam get-role --role-name ${role_name}"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""
echo -e "${YELLOW}=== 8. KMS Keys ===${NC}"

# Check KMS Keys
for key_type in s3 dynamodb; do
    alias_name="alias/${PROJECT_NAME}-${ENVIRONMENT}-${key_type}-kms-key"
    total_checks=$((total_checks + 1))
    if check_resource "KMS Key" "${alias_name}" \
       "aws kms describe-key --key-id ${alias_name} --region ${REGION}"; then
        passed_checks=$((passed_checks + 1))
    fi
done

echo ""
echo -e "${YELLOW}=== Summary ===${NC}"
echo "Total Resources Checked: ${total_checks}"
echo -e "Resources Found: ${GREEN}${passed_checks}${NC}"
echo -e "Resources Missing: ${RED}$((total_checks - passed_checks))${NC}"

percentage=$((passed_checks * 100 / total_checks))
echo -e "Deployment Success Rate: ${percentage}%"

if [ $percentage -eq 100 ]; then
    echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL! All resources are deployed and accessible.${NC}"
    exit_code=0
elif [ $percentage -ge 80 ]; then
    echo -e "${YELLOW}⚠️  DEPLOYMENT MOSTLY SUCCESSFUL with some missing resources.${NC}"
    exit_code=1
else
    echo -e "${RED}❌ DEPLOYMENT FAILED. Many resources are missing.${NC}"
    exit_code=2
fi

echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
if [ $exit_code -eq 0 ]; then
    echo "1. Upload sample data to s3://${PROJECT_NAME}-${ENVIRONMENT}-raw-data/data/incoming/"
    echo "2. Monitor the pipeline execution in AWS Glue console"
    echo "3. Check CloudWatch logs for job execution details"
    echo "4. Set up SNS email subscriptions for notifications"
else
    echo "1. Check Terraform state: terraform state list"
    echo "2. Review Terraform logs for deployment errors"
    echo "3. Re-run deployment: terraform apply -auto-approve"
    echo "4. Check AWS console for any partially created resources"
fi

# Save results to file
cat > deployment_verification_results.txt << EOF
AWS Glue ETL Pipeline - Deployment Verification Results
Generated: $(date)
Environment: ${ENVIRONMENT}
Region: ${REGION}

Total Resources Checked: ${total_checks}
Resources Found: ${passed_checks}
Resources Missing: $((total_checks - passed_checks))
Success Rate: ${percentage}%

Status: $(if [ $exit_code -eq 0 ]; then echo "SUCCESS"; elif [ $exit_code -eq 1 ]; then echo "PARTIAL"; else echo "FAILED"; fi)
EOF

echo ""
echo -e "${BLUE}Results saved to: deployment_verification_results.txt${NC}"

exit $exit_code 