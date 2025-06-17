#!/bin/bash

# Script to fix all Terraform configuration errors
echo "Fixing all Terraform configuration errors..."

# 1. Fix the storage module's main.tf file
echo "Fixing storage module's main.tf file..."

# Create a backup of the original file
cp /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf.bak

# Create a new crawler.tf file for the Glue crawlers
cat > /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/crawler.tf << 'EOF'
# Raw Data Crawler
resource "aws_glue_crawler" "raw_data_crawler" {
  count         = var.create_glue_crawlers ? 1 : 0
  name          = "${var.project_name}-${var.environment}-raw-data-crawler"
  database_name = aws_glue_catalog_database.glue_catalog_database[0].name
  role          = aws_iam_role.glue_crawler_role[0].arn
  schedule      = var.crawler_schedule
  
  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}/${var.raw_data_path_patterns[0]}"
  }
  
  # Add additional S3 targets if more path patterns are provided
  dynamic "s3_target" {
    for_each = length(var.raw_data_path_patterns) > 1 ? slice(var.raw_data_path_patterns, 1, length(var.raw_data_path_patterns)) : []
    content {
      path = "s3://${aws_s3_bucket.raw.bucket}/${s3_target.value}"
    }
  }
  
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
  
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
    VpcConfiguration = length(var.subnet_ids) > 0 ? {
      SubnetId = var.subnet_ids[0]
      SecurityGroupIds = var.security_group_ids
      VpcId = var.vpc_id
    } : null
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-raw-data-crawler"
    Environment = var.environment
  }
}

# Processed Data Crawler
resource "aws_glue_crawler" "processed_data_crawler" {
  count         = var.create_glue_crawlers ? 1 : 0
  name          = "${var.project_name}-${var.environment}-processed-data-crawler"
  database_name = aws_glue_catalog_database.glue_catalog_database[0].name
  role          = aws_iam_role.glue_crawler_role[0].arn
  schedule      = var.crawler_schedule
  
  s3_target {
    path = "s3://${aws_s3_bucket.processed.bucket}/${var.processed_data_path_patterns[0]}"
  }
  
  # Add additional S3 targets if more path patterns are provided
  dynamic "s3_target" {
    for_each = length(var.processed_data_path_patterns) > 1 ? slice(var.processed_data_path_patterns, 1, length(var.processed_data_path_patterns)) : []
    content {
      path = "s3://${aws_s3_bucket.processed.bucket}/${s3_target.value}"
    }
  }
  
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
  
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
    VpcConfiguration = length(var.subnet_ids) > 0 ? {
      SubnetId = var.subnet_ids[0]
      SecurityGroupIds = var.security_group_ids
      VpcId = var.vpc_id
    } : null
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-processed-data-crawler"
    Environment = var.environment
  }
}

# Curated Data Crawler
resource "aws_glue_crawler" "curated_data_crawler" {
  count         = var.create_glue_crawlers ? 1 : 0
  name          = "${var.project_name}-${var.environment}-curated-data-crawler"
  database_name = aws_glue_catalog_database.glue_catalog_database[0].name
  role          = aws_iam_role.glue_crawler_role[0].arn
  schedule      = var.crawler_schedule
  
  s3_target {
    path = "s3://${aws_s3_bucket.curated.bucket}/${var.curated_data_path_patterns[0]}"
  }
  
  # Add additional S3 targets if more path patterns are provided
  dynamic "s3_target" {
    for_each = length(var.curated_data_path_patterns) > 1 ? slice(var.curated_data_path_patterns, 1, length(var.curated_data_path_patterns)) : []
    content {
      path = "s3://${aws_s3_bucket.curated.bucket}/${s3_target.value}"
    }
  }
  
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
  
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
    VpcConfiguration = length(var.subnet_ids) > 0 ? {
      SubnetId = var.subnet_ids[0]
      SecurityGroupIds = var.security_group_ids
      VpcId = var.vpc_id
    } : null
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-curated-data-crawler"
    Environment = var.environment
  }
}
EOF

# Remove the crawler resources from the main.tf file
sed -i '' '/resource "aws_glue_crawler" "raw_data_crawler"/,/^}/d' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf
sed -i '' '/resource "aws_glue_crawler" "processed_data_crawler"/,/^}/d' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf
sed -i '' '/resource "aws_glue_crawler" "curated_data_crawler"/,/^}/d' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

# Fix the S3 bucket lifecycle configuration
echo "Fixing S3 bucket lifecycle configurations..."

# Fix raw bucket lifecycle configuration
sed -i '' '/resource "aws_s3_bucket_lifecycle_configuration" "raw"/,/^}/c\
resource "aws_s3_bucket_lifecycle_configuration" "raw" {\
  bucket = aws_s3_bucket.raw.id\
\
  rule {\
    id     = "transition-to-intelligent-tiering"\
    status = "Enabled"\
\
    filter {\
      prefix = ""\
    }\
\
    transition {\
      days          = 30\
      storage_class = "INTELLIGENT_TIERING"\
    }\
  }\
}' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

# Fix processed bucket lifecycle configuration
sed -i '' '/resource "aws_s3_bucket_lifecycle_configuration" "processed"/,/^}/c\
resource "aws_s3_bucket_lifecycle_configuration" "processed" {\
  bucket = aws_s3_bucket.processed.id\
\
  rule {\
    id     = "transition-to-intelligent-tiering"\
    status = "Enabled"\
\
    filter {\
      prefix = ""\
    }\
\
    transition {\
      days          = 30\
      storage_class = "INTELLIGENT_TIERING"\
    }\
  }\
}' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

# Fix curated bucket lifecycle configuration
sed -i '' '/resource "aws_s3_bucket_lifecycle_configuration" "curated"/,/^}/c\
resource "aws_s3_bucket_lifecycle_configuration" "curated" {\
  bucket = aws_s3_bucket.curated.id\
\
  rule {\
    id     = "transition-to-intelligent-tiering"\
    status = "Enabled"\
\
    filter {\
      prefix = ""\
    }\
\
    transition {\
      days          = 30\
      storage_class = "INTELLIGENT_TIERING"\
    }\
  }\
}' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

# Fix temp bucket lifecycle configuration
sed -i '' '/resource "aws_s3_bucket_lifecycle_configuration" "temp"/,/^}/c\
resource "aws_s3_bucket_lifecycle_configuration" "temp" {\
  bucket = aws_s3_bucket.temp.id\
\
  rule {\
    id     = "expire-temp-files"\
    status = "Enabled"\
\
    filter {\
      prefix = ""\
    }\
\
    expiration {\
      days = 7\
    }\
  }\
}' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

# 2. Fix deprecated vpc argument in aws_eip.nat
echo "Fixing deprecated vpc argument in aws_eip.nat..."
sed -i '' 's/vpc   = true/domain = "vpc"/g' /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/networking/main.tf

echo "All Terraform configuration errors fixed!"
