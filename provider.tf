provider "aws" {
  alias  = "route53-network"
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${var.network_id}:role/R53_Update_Records_${var.sub_env}.aws.allegiant.com"
  }
}
