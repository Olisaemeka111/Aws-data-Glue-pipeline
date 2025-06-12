aws_region = "us-east-1"
project_name = "glue-etl-pipeline"
environment = "prod"

# Secondary region for disaster recovery
secondary_region = "us-west-2"

# Networking
vpc_cidr = "10.2.0.0/16"

# Glue job configuration
glue_version = "4.0"
python_version = "3.10"
worker_type = "G.2X"
number_of_workers = 10
max_concurrent_runs = 5
job_timeout = 120
enable_job_bookmarks = true
enable_spark_ui = true
enable_metrics = true
enable_continuous_logging = true

# Encryption
enable_encryption = true
kms_key_arn = ""

# Monitoring
log_retention_days = 365
alarm_email = "prod-alerts@example.com"
job_duration_threshold = 90
enable_enhanced_monitoring = true

# Storage
raw_data_retention_days = 365

# Disaster recovery
enable_cross_region_replication = true
enable_point_in_time_recovery = true

# Data crawlers
crawler_schedule = "cron(0 2 * * ? *)"  # Run daily at 2 AM
raw_data_path_patterns = ["data/incoming/"]
processed_data_path_patterns = ["data/processed/"]
curated_data_path_patterns = ["data/curated/"]
