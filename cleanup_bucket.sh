#!/bin/bash

BUCKET="glue-etl-pipeline-dev-scripts"

echo "Deleting all object versions and delete markers from $BUCKET..."

# Delete all object versions
aws s3api list-object-versions --bucket $BUCKET --output json | \
jq -r '.Versions[]? | select(.Key != null) | .Key + " " + .VersionId' | \
while read key versionid; do
    echo "Deleting version: $key ($versionid)"
    aws s3api delete-object --bucket $BUCKET --key "$key" --version-id "$versionid"
done

# Delete all delete markers
aws s3api list-object-versions --bucket $BUCKET --output json | \
jq -r '.DeleteMarkers[]? | select(.Key != null) | .Key + " " + .VersionId' | \
while read key versionid; do
    echo "Deleting delete marker: $key ($versionid)"
    aws s3api delete-object --bucket $BUCKET --key "$key" --version-id "$versionid"
done

echo "All versions and delete markers deleted. Now deleting bucket..."
aws s3api delete-bucket --bucket $BUCKET --region us-east-1

echo "Bucket $BUCKET deleted successfully!" 