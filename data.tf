data "aws_ssm_parameter" "vpc_id" {
  name = "/env_info/vpc_id"
}

data "aws_vpc" "default_vpc" {
  id = var.vpc_id == null ? data.aws_ssm_parameter.vpc_id.value : var.vpc_id
}

data "aws_subnets" "vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = ["${data.aws_vpc.default_vpc.id}"]
  }
}

data "aws_subnets" "vpc_subnets_targeted" {
  filter {
    name   = "tag:Name"
    values = var.vpc_subnets_targeted
  }
}

data "aws_subnet" "vpc_subnet" {
  for_each = toset(data.aws_subnets.vpc_subnets.ids)
  id       = each.value
}

data "aws_subnet" "vpc_subnet_az_info" {
  count = length(data.aws_subnets.vpc_subnets.ids)
  id    = tolist(data.aws_subnets.vpc_subnets.ids)[count.index]
}

output "subnet_cidr_blocks" {
  value = [for s in data.aws_subnet.vpc_subnet : s.cidr_block]
}

data "aws_ssm_parameter" "sub_env" {
  name = "/aft/account-request/custom-fields/account/sub_env"
}

data "aws_ssm_parameter" "network_id" {
  name = "/aft/account-request/custom-fields/account_id/network"
}

data "aws_region" "region" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy" "read_ssm" {
  name = "AmazonSSMReadOnlyAccess"
}

data "aws_iam_policy" "core_ssm" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_ssm_parameter" "environment_type" {
  name = "/aft/account-request/custom-fields/environment_type"
}

data "aws_ssm_parameter" "ou_logical_name" {
  name = "/aft/account-request/custom-fields/account/ou_logical_name"
}

data "aws_ssm_parameter" "account_name" {
  name = "/aft/account-request/custom-fields/account/name"
}

data "aws_ssm_parameter" "ami_id" {
  count = (var.ec2_image_builder && var.initial_deployment_ami_id == null) ? 1 : 0
  name  = "/ami-builder/${split("_", var.deployment_name)[0]}-${local.environment}/latest"
}

data "aws_ssm_parameter" "aws_acm_certificate_arn" {
  #count    = var.ssl_service_port == null ? 0 : 1
  name     = "/env_info/dns_wildcard_ssl_cert_arn"
}

data "aws_ssm_parameter" "aws_acm_certificate_arn_allegiantair" {
  count    = var.dns_check == "allegiantair.com" ? 1 : 0
  name     = "/env_info/allegiantair_dns_wildcard_ssl_cert_arn"
}

data "aws_lb" "default" {
  count = var.external_load_balancer == null ? 0 : 1
  name  = var.external_load_balancer
}

data "aws_ssm_parameter" "route53_zone_id" {
  name = "/env_info/route53_zone_id"
}

data "aws_ssm_parameter" "dns_domain" {
  count   = length(var.dns_cnames) > 0 ? 1 : 0
  name = "/env_info/dns_domain"
}

data "aws_ssm_parameter" "control_tower_environment" {
  name = "/aft/account-request/custom-fields/account/control_tower_environment"
}
