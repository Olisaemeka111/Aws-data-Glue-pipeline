#!/bin/bash

# Delete existing problematic triggers
echo "Deleting existing triggers..."
aws glue delete-trigger --name "glue-etl-pipeline-dev-start-ingestion" || true
aws glue delete-trigger --name "glue-etl-pipeline-dev-start-processing" || true
aws glue delete-trigger --name "glue-etl-pipeline-dev-start-quality" || true

echo "Waiting for deletions to complete..."
sleep 10

# Recreate start-ingestion trigger with correct predicate
echo "Creating start-ingestion trigger..."
aws glue create-trigger \
  --name "glue-etl-pipeline-dev-start-ingestion" \
  --description "Trigger to start data ingestion after crawler completes" \
  --type "CONDITIONAL" \
  --workflow-name "glue-etl-pipeline-dev-etl-workflow" \
  --predicate '{
    "Logical": "AND",
    "Conditions": [
      {
        "CrawlerName": "glue-etl-pipeline-dev-raw-data-crawler",
        "CrawlState": "SUCCEEDED"
      }
    ]
  }' \
  --actions '[
    {
      "JobName": "glue-etl-pipeline-dev-data-ingestion"
    }
  ]'

# Recreate start-processing trigger
echo "Creating start-processing trigger..."
aws glue create-trigger \
  --name "glue-etl-pipeline-dev-start-processing" \
  --description "Trigger to start data processing after ingestion completes" \
  --type "CONDITIONAL" \
  --workflow-name "glue-etl-pipeline-dev-etl-workflow" \
  --predicate '{
    "Logical": "AND",
    "Conditions": [
      {
        "JobName": "glue-etl-pipeline-dev-data-ingestion",
        "State": "SUCCEEDED"
      }
    ]
  }' \
  --actions '[
    {
      "JobName": "glue-etl-pipeline-dev-data-processing"
    }
  ]'

# Recreate start-quality trigger
echo "Creating start-quality trigger..."
aws glue create-trigger \
  --name "glue-etl-pipeline-dev-start-quality" \
  --description "Trigger to start data quality checks after processing completes" \
  --type "CONDITIONAL" \
  --workflow-name "glue-etl-pipeline-dev-etl-workflow" \
  --predicate '{
    "Logical": "AND",
    "Conditions": [
      {
        "JobName": "glue-etl-pipeline-dev-data-processing",
        "State": "SUCCEEDED"
      }
    ]
  }' \
  --actions '[
    {
      "JobName": "glue-etl-pipeline-dev-data-quality"
    }
  ]'

echo "All triggers recreated successfully!"
echo "Import them back into Terraform:"
echo "terraform import module.glue.aws_glue_trigger.start_ingestion glue-etl-pipeline-dev-start-ingestion"
echo "terraform import module.glue.aws_glue_trigger.start_processing glue-etl-pipeline-dev-start-processing"
echo "terraform import module.glue.aws_glue_trigger.start_quality glue-etl-pipeline-dev-start-quality" 