# Main Terraform Configuration
# This file serves as the entry point for the Terraform configuration
# All resources are defined in separate files for better organization

# Data sources
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Local values for common configurations
locals {
  account_id = data.aws_caller_identity.current.account_id
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  name_prefix = "${var.project_name}-${var.environment}"
}
