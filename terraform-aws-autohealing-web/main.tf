module "web_tier" {
  source                   = "./modules/web_tier"
  project_name             = var.project_name
  environment              = "dev"
  vpc_cidr                 = var.vpc_cidr
  public_subnet_newbits    = var.public_subnet_newbits
  base_capacity            = var.base_capacity
  additional_buffer        = var.additional_buffer
  instance_type            = var.instance_type
  enable_detailed_monitoring = var.enable_detailed_monitoring
  tags = {
    Owner = "${data.aws_caller_identity.current.account_id}"
  }
}


