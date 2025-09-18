variable "project_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_newbits" {
  type    = number
  default = 8
}

variable "base_capacity" {
  type    = number
  default = 1
}

variable "additional_buffer" {
  type    = number
  default = 1
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "enable_detailed_monitoring" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}


