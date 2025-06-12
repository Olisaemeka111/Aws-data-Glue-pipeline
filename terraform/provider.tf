terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # These values should be provided during initialization
    # terraform init -backend-config="bucket=your-terraform-state-bucket" -backend-config="key=glue-etl/terraform.tfstate" -backend-config="region=us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "AWS-Glue-ETL-Pipeline"
      ManagedBy   = "Terraform"
    }
  }
}

# Provider for secondary region (for disaster recovery)
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "AWS-Glue-ETL-Pipeline"
      ManagedBy   = "Terraform"
    }
  }
}
