#!/bin/bash
# Script to package Lambda functions for deployment

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Environment argument
ENVIRONMENT=${1:-dev}
echo "Packaging Lambda functions for environment: $ENVIRONMENT"

# Create build directory
BUILD_DIR="$PROJECT_ROOT/build/lambda"
mkdir -p "$BUILD_DIR"

# Package data_trigger Lambda
echo "Packaging data_trigger Lambda function..."
LAMBDA_DIR="$PROJECT_ROOT/src/lambda/data_trigger"
OUTPUT_ZIP="$BUILD_DIR/data_trigger_lambda.zip"

# Create a temporary directory for packaging
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"

# Copy Lambda code to temp directory
cp "$LAMBDA_DIR/lambda_function.py" "$TEMP_DIR/"

# Install dependencies in the temporary directory
echo "Installing dependencies..."
pip install boto3 -t "$TEMP_DIR" --no-cache-dir

# Create the zip file
echo "Creating zip file: $OUTPUT_ZIP"
cd "$TEMP_DIR"
zip -r "$OUTPUT_ZIP" .
cd - > /dev/null

# Clean up
rm -rf "$TEMP_DIR"

echo "Lambda function packaged successfully: $OUTPUT_ZIP"

# Update Terraform variables with Lambda zip path
TFVARS_FILE="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT/terraform.tfvars"

# Check if tfvars file exists
if [ -f "$TFVARS_FILE" ]; then
    # Check if lambda_zip_path already exists in the file
    if grep -q "lambda_zip_path" "$TFVARS_FILE"; then
        # Update existing variable
        sed -i '' "s|lambda_zip_path = .*|lambda_zip_path = \"$OUTPUT_ZIP\"|" "$TFVARS_FILE"
    else
        # Add new variable
        echo "lambda_zip_path = \"$OUTPUT_ZIP\"" >> "$TFVARS_FILE"
    fi
    echo "Updated Lambda zip path in $TFVARS_FILE"
else
    echo "Warning: $TFVARS_FILE does not exist. Please add lambda_zip_path = \"$OUTPUT_ZIP\" manually."
fi

echo "Lambda packaging complete!"
