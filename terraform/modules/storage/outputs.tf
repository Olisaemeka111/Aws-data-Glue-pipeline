output "raw_bucket" {
  description = "S3 bucket for raw data"
  value = {
    id   = aws_s3_bucket.raw.id
    arn  = aws_s3_bucket.raw.arn
    name = aws_s3_bucket.raw.bucket
  }
}

output "processed_bucket" {
  description = "S3 bucket for processed data"
  value = {
    id   = aws_s3_bucket.processed.id
    arn  = aws_s3_bucket.processed.arn
    name = aws_s3_bucket.processed.bucket
  }
}

output "curated_bucket" {
  description = "S3 bucket for curated data"
  value = {
    id   = aws_s3_bucket.curated.id
    arn  = aws_s3_bucket.curated.arn
    name = aws_s3_bucket.curated.bucket
  }
}

output "scripts_bucket" {
  description = "S3 bucket for Glue job scripts"
  value = {
    id   = aws_s3_bucket.scripts.id
    arn  = aws_s3_bucket.scripts.arn
    name = aws_s3_bucket.scripts.bucket
  }
}

output "temp_bucket" {
  description = "S3 bucket for temporary files"
  value = {
    id   = aws_s3_bucket.temp.id
    arn  = aws_s3_bucket.temp.arn
    name = aws_s3_bucket.temp.bucket
  }
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = var.enable_encryption ? aws_kms_key.s3[0].arn : null
}

# Glue Data Catalog and Crawler outputs
output "glue_catalog_database_name" {
  description = "Name of the Glue Data Catalog database"
  value       = var.create_glue_catalog_database ? aws_glue_catalog_database.glue_catalog_database[0].name : null
}

output "glue_crawler_role_arn" {
  description = "ARN of the IAM role used by Glue crawlers"
  value       = var.create_glue_crawlers ? aws_iam_role.glue_crawler_role[0].arn : null
}

output "raw_data_crawler" {
  description = "Raw data Glue crawler details"
  value       = var.create_glue_crawlers ? {
    name = aws_glue_crawler.raw_data_crawler[0].name
    arn  = aws_glue_crawler.raw_data_crawler[0].arn
  } : null
}

output "processed_data_crawler" {
  description = "Processed data Glue crawler details"
  value       = var.create_glue_crawlers ? {
    name = aws_glue_crawler.processed_data_crawler[0].name
    arn  = aws_glue_crawler.processed_data_crawler[0].arn
  } : null
}

output "curated_data_crawler" {
  description = "Curated data Glue crawler details"
  value       = var.create_glue_crawlers ? {
    name = aws_glue_crawler.curated_data_crawler[0].name
    arn  = aws_glue_crawler.curated_data_crawler[0].arn
  } : null
}
