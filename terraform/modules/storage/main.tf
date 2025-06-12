resource "aws_kms_key" "s3" {
  count                   = var.enable_encryption ? 1 : 0
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Glue Service to use the key"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-s3-kms-key"
  }
}

resource "aws_kms_alias" "s3" {
  count         = var.enable_encryption ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-s3"
  target_key_id = aws_kms_key.s3[0].key_id
}

# Raw data bucket
resource "aws_s3_bucket" "raw" {
  bucket = "${var.bucket_prefix}-${var.environment}-raw"

  tags = {
    Name        = "${var.project_name}-${var.environment}-raw"
    DataTier    = "raw"
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
  bucket = "${var.bucket_prefix}-${var.environment}-processed"

  tags = {
    Name        = "${var.project_name}-${var.environment}-processed"
    DataTier    = "processed"
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

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
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
  bucket = "${var.bucket_prefix}-${var.environment}-curated"

  tags = {
    Name        = "${var.project_name}-${var.environment}-curated"
    DataTier    = "curated"
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

# Scripts bucket for Glue job scripts
resource "aws_s3_bucket" "scripts" {
  bucket = "${var.bucket_prefix}-${var.environment}-scripts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-scripts"
    DataTier    = "scripts"
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

resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket                  = aws_s3_bucket.scripts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Temporary bucket for Glue job temporary files
resource "aws_s3_bucket" "temp" {
  bucket = "${var.bucket_prefix}-${var.environment}-temp"

  tags = {
    Name        = "${var.project_name}-${var.environment}-temp"
    DataTier    = "temp"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "temp" {
  bucket = aws_s3_bucket.temp.id

  rule {
    id     = "delete-old-files"
    status = "Enabled"

    expiration {
      days = 7
    }
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

resource "aws_s3_bucket_public_access_block" "temp" {
  bucket                  = aws_s3_bucket.temp.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Glue Data Catalog Database
resource "aws_glue_catalog_database" "glue_catalog_database" {
  count = var.create_glue_catalog_database ? 1 : 0
  name  = "${var.project_name}_${var.environment}_catalog"
  
  description = "Glue Data Catalog database for ${var.project_name} ${var.environment} environment"
}

# IAM Role for Glue Crawlers
resource "aws_iam_role" "glue_crawler_role" {
  count = var.create_glue_crawlers ? 1 : 0
  name  = "${var.project_name}-${var.environment}-crawler-role"

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
    Name        = "${var.project_name}-${var.environment}-crawler-role"
    Environment = var.environment
  }
}

# Attach AWS managed policy for Glue service
resource "aws_iam_role_policy_attachment" "glue_service" {
  count      = var.create_glue_crawlers ? 1 : 0
  role       = aws_iam_role.glue_crawler_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom policy for S3 access
resource "aws_iam_policy" "crawler_s3_access" {
  count       = var.create_glue_crawlers ? 1 : 0
  name        = "${var.project_name}-${var.environment}-crawler-s3-access"
  description = "Policy for Glue Crawler to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
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

resource "aws_iam_role_policy_attachment" "crawler_s3_access" {
  count      = var.create_glue_crawlers ? 1 : 0
  role       = aws_iam_role.glue_crawler_role[0].name
  policy_arn = aws_iam_policy.crawler_s3_access[0].arn
}

# KMS policy for crawlers if encryption is enabled
resource "aws_iam_policy" "crawler_kms_access" {
  count       = var.create_glue_crawlers && var.enable_encryption ? 1 : 0
  name        = "${var.project_name}-${var.environment}-crawler-kms-access"
  description = "Policy for Glue Crawler to use KMS keys"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.s3[0].arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "crawler_kms_access" {
  count      = var.create_glue_crawlers && var.enable_encryption ? 1 : 0
  role       = aws_iam_role.glue_crawler_role[0].name
  policy_arn = aws_iam_policy.crawler_kms_access[0].arn
}

# VPC access policy for crawlers if VPC configuration is provided
resource "aws_iam_policy" "crawler_vpc_access" {
  count       = var.create_glue_crawlers && length(var.subnet_ids) > 0 ? 1 : 0
  name        = "${var.project_name}-${var.environment}-crawler-vpc-access"
  description = "Policy for Glue Crawler to access VPC resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVPCs"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "crawler_vpc_access" {
  count      = var.create_glue_crawlers && length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.glue_crawler_role[0].name
  policy_arn = aws_iam_policy.crawler_vpc_access[0].arn
}

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
  
  # VPC configuration if subnet IDs are provided
  dynamic "configuration" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      vpc_configuration {
        subnet_id              = var.subnet_ids[0]
        security_group_ids     = var.security_group_ids
        vpc_id                 = var.vpc_id
      }
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
  
  # VPC configuration if subnet IDs are provided
  dynamic "configuration" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      vpc_configuration {
        subnet_id              = var.subnet_ids[0]
        security_group_ids     = var.security_group_ids
        vpc_id                 = var.vpc_id
      }
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
  
  # VPC configuration if subnet IDs are provided
  dynamic "configuration" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      vpc_configuration {
        subnet_id              = var.subnet_ids[0]
        security_group_ids     = var.security_group_ids
        vpc_id                 = var.vpc_id
      }
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
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-curated-data-crawler"
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}
