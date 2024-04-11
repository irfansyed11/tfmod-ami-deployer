
terraform {
  backend "s3" {
    encrypt        = "true"
    bucket         = "248452401457-tf-remote-state"
    dynamodb_table = "tf-state-lock"
    key            = "tf/ami-deployers/msk-sample"
    region         = "us-west-2"
  }
}

module "sample" {
  source                        = "../../"
  use_load_balancer = false
  use_autoscaling_group = false
  create_msk_cluster    = true
  #enable_route53_record  = true
  domain_name = "test"
  business_unit            = "TODO: Find business_unit for fmm-flight-translator"
  compliance_status        = "compliant"
  cost_center              = "TODO: Find cost_center for fmm-flight-translator"
  deployment_name          = "kafka-cluster"
  feature_version          = "TODO: Find feature_version for fmm-flight-translator"
  initiative_id            = "TODO: Find initiative_id for fmm-flight-translator"
  persistent_team_name     = "TODO: Find persistent_team_name for fmm-flight-translator"
  product_name             = "fmm-flight-translator"
  stack_name               = "TODO: Find stack_name for fmm-flight-translator"
  stack_role               = "TODO: Find stack_role for fmm-flight-translator"
  vertical_name            = "TODO: Find vertical_name for fmm-flight-translator"
  ec2_image_builder        = "false"
  app_in_ports      = {
    springboot_tcp = {
      desc     = "server springboot tcp"
      from     = "80"
      to       = "80"
      protocol = "tcp"
      cidrs    = ["10.0.0.0/8"]
    },
    ssh_tcp = {
      desc     = "server springboot tcp"
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
