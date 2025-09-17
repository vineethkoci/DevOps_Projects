output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}


