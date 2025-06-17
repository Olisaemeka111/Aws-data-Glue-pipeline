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
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-curated-data-crawler"
    Environment = var.environment
  }
}
