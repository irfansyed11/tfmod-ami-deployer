
terraform {
  backend "s3" {
    encrypt        = "true"
    bucket         = "878031627345-tf-remote-state"
    dynamodb_table = "tf-state-lock"
    key            = "tf/ami-deployers/elastic-memcached"
    region         = "us-west-2"
  }
}

module "sample" {
  source                        = "../../"
  use_load_balancer = false
  use_autoscaling_group = false
  use_elasticcache_cluster  = true
  domain_name = "test"
  business_unit            = "TODO: Find business_unit for elastic-memcached"
  compliance_status        = "compliant"
  cost_center              = "TODO: Find cost_center for elastic-memcached"
  deployment_name          = "elastic-memcached"
  feature_version          = "TODO: Find feature_version for elastic-memcached"
  initiative_id            = "TODO: Find initiative_id for elastic-memcached"
  persistent_team_name     = "TODO: Find persistent_team_name for elastic-memcached"
  product_name             = "elastic-memcached"
  stack_name               = "TODO: Find stack_name for elastic-memcached"
  stack_role               = "TODO: Find stack_role for elastic-memcached"
  vertical_name            = "TODO: Find vertical_name for elastic-memcached"
  ec2_image_builder        = "false"
  app_in_ports      = {
    springboot_tcp = {
      desc     = "server elastic-memcached tcp"
      from     = "80"
      to       = "80"
      protocol = "tcp"
      cidrs    = ["10.0.0.0/8"]
    },
    ssh_tcp = {
      desc     = "server elastic-memcached tcp"
      from     = "22"
      to       = "22"
      protocol = "tcp"
      cidrs    = ["10.0.0.0/8"]
    }
  }
  need_ec2_tags  = false

}

provider "aws" {
  region     = "us-west-2"
}
