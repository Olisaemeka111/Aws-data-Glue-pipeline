#!/bin/bash

# Script to fix Terraform configuration errors
echo "Fixing Terraform configuration errors..."

# 1. Fix S3 bucket lifecycle configurations by adding filter blocks
echo "Fixing S3 bucket lifecycle configurations..."

# Raw bucket lifecycle
sed -i '' 's/rule {/rule {\n    filter {\n      prefix = ""\n    }/g' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

# 2. Remove dynamic configuration blocks from Glue crawlers
echo "Fixing Glue crawler configurations..."

# Use the fixed crawler configuration file
echo "Moving fixed crawler configuration..."
mv /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/fixed_crawler.tf /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/crawlers.tf

# Remove the old crawler configurations from main.tf
echo "Removing old crawler configurations..."
sed -i '' '/resource "aws_glue_crawler" "raw_data_crawler"/,/^}/d' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf
sed -i '' '/resource "aws_glue_crawler" "processed_data_crawler"/,/^}/d' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf
sed -i '' '/resource "aws_glue_crawler" "curated_data_crawler"/,/^}/d' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

# 3. Fix deprecated vpc argument in aws_eip.nat
echo "Fixing deprecated vpc argument in aws_eip.nat..."
sed -i '' 's/vpc   = true/domain = "vpc"/g' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/networking/main.tf

echo "Terraform configuration errors fixed!"
