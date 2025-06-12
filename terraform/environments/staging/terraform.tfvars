aws_region = "us-east-1"
project_name = "glue-etl-pipeline"
environment = "staging"

# Networking
vpc_cidr = "10.1.0.0/16"

# Glue job configuration
glue_version = "4.0"
python_version = "3.10"
worker_type = "G.1X"
number_of_workers = 5
max_concurrent_runs = 3
job_timeout = 60
enable_job_bookmarks = true
enable_spark_ui = true
enable_metrics = true
enable_continuous_logging = true

# Encryption
enable_encryption = true
kms_key_arn = ""

# Monitoring
log_retention_days = 90
alarm_email = "staging-alerts@example.com"
job_duration_threshold = 45
enable_enhanced_monitoring = true

# Storage
raw_data_retention_days = 90

# Data crawlers
crawler_schedule = "cron(0 0 * * ? *)"  # Run daily at midnight
raw_data_path_patterns = ["data/incoming/"]
processed_data_path_patterns = ["data/processed/"]
curated_data_path_patterns = ["data/curated/"]
