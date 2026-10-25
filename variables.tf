variable "aws_region" {
  description = "AWS region for resources."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
  default     = "github-oidc-demo"
}

variable "environment" {
  description = "Environment name used in tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name. Set this in terraform.tfvars."
  type        = string
}