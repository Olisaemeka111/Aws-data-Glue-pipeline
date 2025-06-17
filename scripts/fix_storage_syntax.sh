#!/bin/bash

# Script to fix the syntax errors in the storage module's main.tf file
echo "Fixing syntax errors in storage module's main.tf file..."

# Create a backup of the original file
cp /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf.bak

# Fix the S3 bucket server-side encryption configuration
cat > /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf << 'EOF'
# Storage module - S3 buckets, DynamoDB tables, and Glue catalog resources

# Raw data bucket
resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_name}-${var.environment}-raw-data"

  tags = {
    Name        = "${var.project_name}-${var.environment}-raw-data"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_encryption ? aws_kms_key.s3[0].arn : null
      sse_algorithm     = var.enable_encryption ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "transition-to-intelligent-tiering"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Processed data bucket
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-${var.environment}-processed-data"

  tags = {
    Name        = "${var.project_name}-${var.environment}-processed-data"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_encryption ? aws_kms_key.s3[0].arn : null
      sse_algorithm     = var.enable_encryption ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    id     = "transition-to-intelligent-tiering"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Curated data bucket
resource "aws_s3_bucket" "curated" {
  bucket = "${var.project_name}-${var.environment}-curated-data"

  tags = {
    Name        = "${var.project_name}-${var.environment}-curated-data"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "curated" {
  bucket = aws_s3_bucket.curated.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "curated" {
  bucket = aws_s3_bucket.curated.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_encryption ? aws_kms_key.s3[0].arn : null
      sse_algorithm     = var.enable_encryption ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "curated" {
  bucket = aws_s3_bucket.curated.id

  rule {
    id     = "transition-to-intelligent-tiering"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "curated" {
  bucket                  = aws_s3_bucket.curated.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Scripts bucket
resource "aws_s3_bucket" "scripts" {
  bucket = "${var.project_name}-${var.environment}-scripts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-scripts"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_encryption ? aws_kms_key.s3[0].arn : null
      sse_algorithm     = var.enable_encryption ? "aws:kms" : "AES256"
    }
  }
}

# Temporary files bucket
resource "aws_s3_bucket" "temp" {
  bucket = "${var.project_name}-${var.environment}-temp"

  tags = {
    Name        = "${var.project_name}-${var.environment}-temp"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "temp" {
  bucket = aws_s3_bucket.temp.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "temp" {
  bucket = aws_s3_bucket.temp.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_encryption ? aws_kms_key.s3[0].arn : null
      sse_algorithm     = var.enable_encryption ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "temp" {
  bucket = aws_s3_bucket.temp.id

  rule {
    id     = "expire-temp-files"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "temp" {
  bucket                  = aws_s3_bucket.temp.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# KMS key for S3 encryption
resource "aws_kms_key" "s3" {
  count                   = var.enable_encryption ? 1 : 0
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-kms-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "s3" {
  count         = var.enable_encryption ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-s3-kms-key"
  target_key_id = aws_kms_key.s3[0].key_id
}

# DynamoDB tables for metadata and job bookmarks
resource "aws_dynamodb_table" "metadata" {
  name         = "${var.project_name}-${var.environment}-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.enable_encryption ? aws_kms_key.dynamodb[0].arn : null
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-metadata"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "job_bookmarks" {
  name         = "${var.project_name}-${var.environment}-job-bookmarks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_name"
  range_key    = "run_id"

  attribute {
    name = "job_name"
    type = "S"
  }

  attribute {
    name = "run_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.enable_encryption ? aws_kms_key.dynamodb[0].arn : null
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-job-bookmarks"
    Environment = var.environment
  }
}

# KMS key for DynamoDB encryption
resource "aws_kms_key" "dynamodb" {
  count                   = var.enable_encryption ? 1 : 0
  description             = "KMS key for DynamoDB table encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-dynamodb-kms-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "dynamodb" {
  count         = var.enable_encryption ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-dynamodb-kms-key"
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

# Glue catalog database
resource "aws_glue_catalog_database" "glue_catalog_database" {
  count = var.create_glue_catalog ? 1 : 0
  name  = "${var.project_name}_${var.environment}_catalog"
}

# IAM role for Glue crawlers
resource "aws_iam_role" "glue_crawler_role" {
  count = var.create_glue_crawlers ? 1 : 0
  name  = "${var.project_name}-${var.environment}-glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-glue-crawler-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  count      = var.create_glue_crawlers ? 1 : 0
  role       = aws_iam_role.glue_crawler_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_policy" "glue_crawler_s3_policy" {
  count       = var.create_glue_crawlers ? 1 : 0
  name        = "${var.project_name}-${var.environment}-glue-crawler-s3-policy"
  description = "Policy for Glue crawler to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*",
          aws_s3_bucket.processed.arn,
          "${aws_s3_bucket.processed.arn}/*",
          aws_s3_bucket.curated.arn,
          "${aws_s3_bucket.curated.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_crawler_s3_policy" {
  count      = var.create_glue_crawlers ? 1 : 0
  role       = aws_iam_role.glue_crawler_role[0].name
  policy_arn = aws_iam_policy.glue_crawler_s3_policy[0].arn
}

# Include the crawler definitions from the separate file
EOF

# Append the crawler definitions from the fixed_crawler.tf file
cat /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/fixed_crawler.tf >> /Users/olisa/Desktop/AWS\ Data\ Glue\ pipeline/terraform/modules/storage/main.tf

echo "Syntax errors in storage module's main.tf file fixed!"
