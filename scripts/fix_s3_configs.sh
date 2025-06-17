#!/bin/bash

# Script to fix S3 bucket configuration errors
echo "Fixing S3 bucket configuration errors..."

# Remove incorrectly added filter blocks from server-side encryption configurations
echo "Removing incorrect filter blocks from server-side encryption configurations..."

# Create a temporary file
TMP_FILE=$(mktemp)

# Process the storage main.tf file
cat /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf | 
  awk '
    /resource "aws_s3_bucket_server_side_encryption_configuration"/ {in_sse=1}
    /resource "aws_s3_bucket_lifecycle_configuration"/ {in_lifecycle=1}
    /^}/ {if (in_sse==1) in_sse=0; if (in_lifecycle==1) in_lifecycle=0}
    !(in_sse==1 && /filter {/) {print}
    in_lifecycle==1 && /rule {/ {print; print "    filter {\n      prefix = \"\"\n    }"}
    in_lifecycle==1 && /rule {/ {getline}
  ' > $TMP_FILE

# Replace the original file with the fixed content
mv $TMP_FILE /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

echo "S3 bucket configuration errors fixed!"
