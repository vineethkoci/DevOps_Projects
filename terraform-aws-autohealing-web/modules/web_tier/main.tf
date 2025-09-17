locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "web_tier"
    },
    var.tags
  )

  desired_capacity = var.base_capacity + var.additional_buffer
  min_capacity     = var.base_capacity + var.additional_buffer
  max_capacity     = var.base_capacity + var.additional_buffer
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  owners      = ["137112412989"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.public_subnet_newbits, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-${count.index}" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow HTTP from the internet"
  vpc_id      = aws_vpc.this.id
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_security_group" "web_sg" {
  name        = "${local.name_prefix}-web-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.this.id
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web-sg" })
}

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = merge(local.common_tags, { Name = "${local.name_prefix}-alb" })
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
    path                = "/"
    matcher             = "200-399"
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.instance_role.name
  tags = local.common_tags
}

resource "aws_launch_template" "web" {
  name_prefix           = "${local.name_prefix}-lt-"
  image_id              = data.aws_ami.al2023.id
  instance_type         = var.instance_type
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(templatefile("${path.module}/templates/userdata.sh", {
    project = var.project_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${local.name_prefix}-asg"
  vpc_zone_identifier       = [for s in aws_subnet.public : s.id]
  desired_capacity          = local.desired_capacity
  min_size                  = local.min_capacity
  max_size                  = local.max_capacity
  health_check_type         = "ELB"
  health_check_grace_period = 60

  target_group_arns = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-web"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


