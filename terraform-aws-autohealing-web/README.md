# Auto-healing N+1 Web Tier on AWS (Terraform)

This Terraform setup creates (via module `modules/web_tier`):
- VPC with 2 public subnets across 2 AZs
- Application Load Balancer (HTTP :80)
- Launch Template that self-provisions Nginx (Amazon Linux 2023)
- Auto Scaling Group with N+1 capacity and ELB health checks

Must-haves: 
- Self healing: ASG replaces unhealthy instances automatically
- Self provisioning: User data installs and starts Nginx
- N+1 capacity: Desired/min = N + 1 (configurable); can lose 1 VM without downtime
- Static web: Default Nginx welcome page on port 80
- Template: Terraform >= 1.5, AWS provider >= 5.x

## Usage

Prerequisites:
- AWS credentials via a named profile (`aws_profile`) or environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional `AWS_SESSION_TOKEN`).
- Provide `aws_region` explicitly (root variable has no default).

PowerShell:
```powershell
terraform -chdir=terraform-aws-autohealing-web init
terraform -chdir=terraform-aws-autohealing-web plan -out tf.plan -var "project_name=autoheal-web" -var "aws_region=ap-south-1" -var "base_capacity=1" -var "additional_buffer=1" -var "aws_profile=default"
terraform -chdir=terraform-aws-autohealing-web apply tf.plan
terraform -chdir=terraform-aws-autohealing-web output alb_dns_name
```

Bash:
```bash
cd terraform-aws-autohealing-web
terraform init
terraform plan -out tf.plan \
  -var "project_name=autoheal-web" \
  -var "aws_region=ap-south-1" \
  -var "base_capacity=1" \
  -var "additional_buffer=1" \
  -var "aws_profile=default"
terraform apply tf.plan
terraform output alb_dns_name
```

Open the ALB DNS in your browser. You should see the Nginx welcome page.

## Architecture (ASCII)

```
            Internet
                |
            [ ALB :80 ]  <- SG: 0.0.0.0/0 -> 80
             /       \
     AZ-a  SubnetA   SubnetB  AZ-b
            |           |
        EC2 (nginx)  EC2 (nginx)
           ^            ^
           |            |
          SG (only from ALB)

VPC (10.20.0.0/16), IGW, Public RT (0.0.0.0/0)
```

## Variables
- `aws_region`: AWS region (required)
- `project_name`: Resource name prefix
- `environment`: Environment name (default `dev`)
- `vpc_cidr`: CIDR for VPC (default `10.20.0.0/16`)
- `public_subnet_newbits`: Newbits for subnetting (default `8`)
- `base_capacity`: Required capacity N (default 1)
- `additional_buffer`: Extra instances above N (default 1 for N+1)
- `instance_type`: EC2 type (default `t3.micro`)
- `enable_detailed_monitoring`: Enable EC2 detailed monitoring (default `false`)
- `tags`: Map of extra tags (default `{}`)
- `aws_profile`: AWS shared config profile name (optional; default `null`)

## Outputs
- `alb_dns_name`: Public DNS of the ALB
- `asg_name`: Auto Scaling Group name
- `vpc_id`: VPC ID

## Assumptions
- Public subnets and ALB on port 80 are acceptable for this demo.
- Amazon Linux 2023, x86_64, Nginx default welcome page.
- No SSH access is required.

AMI resolution uses the regional SSM public parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` to select the latest AL2023 AMI owned by `amazon`.

## Estimated monthly cost (AU$ ≤ 20)
- 2 x t3.micro in `ap-south-1`: ~AU$ 10–12 total (on-demand, 730h)
- ALB: ~AU$ 4–6 (low LCU usage + hours)
- Data transfer minimal (demo): ~AU$ 0–2
- Total estimate: ~AU$ 16–20 per month

Costs vary by region and traffic; consider t4g.micro (ARM) for further savings.

## CI Pipeline (optional)
Example GitHub Actions workflow for validate/plan-only with Terraform 1.5+:

```
.github/workflows/terraform.yml
---
name: terraform-validate-plan
on:
  pull_request:
  push:
    branches: [ main ]
jobs:
  tf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.5
      - name: Terraform Init
        run: terraform -chdir=terraform-aws-autohealing-web init -input=false
      - name: Terraform Validate
        run: terraform -chdir=terraform-aws-autohealing-web validate
      - name: Terraform Plan
        env:
          TF_VAR_project_name: autoheal-web
          TF_VAR_aws_region: us-east-1
        run: terraform -chdir=terraform-aws-autohealing-web plan -input=false -lock=false -no-color
```

## Commit history suggestion
1. Scaffold provider and root variables
2. Add module skeleton `modules/web_tier`
3. Implement VPC/subnets/IGW/RT in module
4. Add SGs and ALB/TG/listener in module
5. Add Launch Template and ASG (N+1) in module
6. Wire root to module and outputs
7. Add userdata for Nginx
8. Add README, ASCII diagram, cost and assumptions
9. Add CI validate/plan workflow

## Cleanup
```bash
terraform destroy -auto-approve
```