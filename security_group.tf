resource "aws_security_group" "stack-sg" {
  #tfsec:ignore:aws-vpc-no-public-egress-sgr
  name                   = join("-", [local.aws_resource_name_prefix, "sg"])
  description            = "Allow traffic for ${var.deployment_name} service."
  vpc_id                 = data.aws_vpc.default_vpc.id
  revoke_rules_on_delete = true
  tags = merge(
    {
      "Name" = local.aws_resource_name_prefix
    },
    local.default_resource_tags
  )

  dynamic "ingress" {
    for_each = var.app_in_ports
    content {
      description     = lookup(ingress.value, "desc", null)
      from_port       = lookup(ingress.value, "from", null)
      to_port         = lookup(ingress.value, "to", null)
      protocol        = lookup(ingress.value, "protocol", null)
      cidr_blocks     = lookup(ingress.value, "cidrs", null)
      security_groups = lookup(ingress.value, "sgs", null)
    }
  }

  dynamic "egress" {
    for_each = var.app_out_ports
    content {
      description     = lookup(egress.value, "desc", null)
      from_port       = lookup(egress.value, "from", null)
      to_port         = lookup(egress.value, "to", null)
      protocol        = lookup(egress.value, "protocol", null)
      cidr_blocks     = lookup(egress.value, "cidrs", null) #tfsec:ignore:aws-vpc-no-public-egress-sgr
      security_groups = lookup(egress.value, "sgs", null)
    }
  }
}
