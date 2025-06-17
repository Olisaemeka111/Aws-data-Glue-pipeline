#!/bin/bash

# Quick Deployment Status Check
echo "🔍 AWS Glue ETL Pipeline - Deployment Status Check"
echo "=================================================="

# Check if Terraform is still running
if pgrep -f "terraform apply" > /dev/null; then
    echo "✅ Terraform deployment is currently RUNNING in background"
    echo "📊 Process ID: $(pgrep -f "terraform apply")"
else
    echo "⏹️  No Terraform deployment process detected"
fi

echo ""
echo "🏗️  Quick Resource Check:"

# Check for key resources
echo -n "S3 Buckets: "
bucket_count=$(aws s3 ls | grep -c "glue-etl-pipeline-dev" 2>/dev/null || echo "0")
echo "${bucket_count}/5 expected"

echo -n "Glue Database: "
if aws glue get-database --name "glue-etl-pipeline_dev_catalog" --region us-east-1 >/dev/null 2>&1; then
    echo "✅ Created"
else
    echo "❌ Not found"
fi

echo -n "VPC: "
if aws ec2 describe-vpcs --filters "Name=tag:Name,Values=glue-etl-pipeline-dev-vpc" --region us-east-1 --query 'Vpcs[0].VpcId' --output text 2>/dev/null | grep -v "None" >/dev/null; then
    echo "✅ Created"
else
    echo "❌ Not found"
fi

echo ""
echo "📋 To check full deployment status, run:"
echo "   cd terraform/environments/dev && terraform state list | wc -l"
echo ""
echo "📊 To see all created resources:"
echo "   ./scripts/verify_deployment.sh" 