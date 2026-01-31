variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "serverless-order-system"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "admin_email" {
  description = "Email address for SNS notifications"
  type        = string
  default     = "admin@example.com"
}

variable "high_value_threshold" {
  description = "Order amount threshold for high-value processing"
  type        = number
  default     = 1000
}
