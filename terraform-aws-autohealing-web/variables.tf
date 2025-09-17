variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A short name used to tag and name resources"
  type        = string
  default     = "autoheal-web"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_newbits" {
  description = "Newbits for cidrsubnet to carve public subnets"
  type        = number
  default     = 8
}

variable "base_capacity" {
  description = "Required capacity N. The system provisions N+1 for resilience"
  type        = number
  default     = 1
}

variable "additional_buffer" {
  description = "How many extra instances above N to run (default 1 = N+1)"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type for web tier"
  type        = string
  default     = "t3.micro"
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring on instances"
  type        = bool
  default     = false
}


