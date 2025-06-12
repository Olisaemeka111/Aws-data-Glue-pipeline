aws_region = "us-east-1"
project_name = "glue-etl-pipeline"
environment = "dev"

# Networking
vpc_cidr = "10.0.0.0/16"

# Glue job configuration
glue_version = "4.0"
python_version = "3.10"
worker_type = "G.1X"
number_of_workers = 2
max_concurrent_runs = 1
job_timeout = 30
enable_job_bookmarks = true
enable_spark_ui = true
enable_metrics = true
enable_continuous_logging = true

# Encryption
enable_encryption = true
kms_key_arn = ""

# Monitoring
log_retention_days = 30
alarm_email = "dev-alerts@example.com"
job_duration_threshold = 20
enable_enhanced_monitoring = true

# Storage
raw_data_retention_days = 30

# Data crawlers
crawler_schedule = "cron(0 1 * * ? *)"  # Run daily at 1 AM
raw_data_path_patterns = ["data/incoming/"]
processed_data_path_patterns = ["data/processed/"]
curated_data_path_patterns = ["data/curated/"]
