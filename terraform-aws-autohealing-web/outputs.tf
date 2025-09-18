output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.web_tier.alb_dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.web_tier.asg_name
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.web_tier.vpc_id
}


