terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "aws_profile" {
  description = "AWS shared config profile name (optional)"
  type        = string
  default     = null
}


