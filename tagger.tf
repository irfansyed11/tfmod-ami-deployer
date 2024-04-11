module "aws_tagger" {
  source = "git::git@github.com:AllegiantTravelCo/tfmod-aws-tagger.git?ref=experimental"

  stack_name          = var.stack_name
  vertical_name       = var.vertical_name
  domain_name         = var.domain_name
  business_unit       = var.business_unit
  cost_center         = var.cost_center
  product_name        = var.product_name
  # Disabled the feature_name logic as it fails when the name of the deployer only have 1 word
  #feature_name        = join("-", slice(split("-", var.deployment_name), 1, length(split("-", var.deployment_name)) - 1))
  feature_name        = var.deployment_name
  initiative_id       = var.initiative_id
  stack_role          = local.stack_role
  feature_version     = var.feature_version
  environment         = local.environment
  resource_group      = var.resource_group
  is_live             = var.is_live
  fqdn                = var.fqdn
  build_info          = var.build_info
  ou_name             = local.ou_logical_name
  pattern_type        = element(split("-", var.deployment_name), 0)
  change_ticket       = var.change_ticket
  expiration_date     = local.ami_expiration_date
  data_classification = local.data_classification

  compliance_status    = var.compliance_status
  persistent_team_name = var.persistent_team_name

  #EC2 TAGS
  patch_group         = var.patch_group
  backup_schedule     = var.backup_schedule
  ec2_schedule        = var.ec2_schedule
  sub_env             = local.sub_env
  working_environment = "aws${local.sub_env}"
  ansible_group       = var.ansible_group
  ansible_groups      = var.ansible_groups
  os                  = var.os
  Name                = var.deployment_name
  need_ec2_tags       = var.need_ec2_tags
}
