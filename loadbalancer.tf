resource "aws_lb" "default" {
  count                      = var.use_load_balancer ? 1 : 0
  name                       = join("-", [substr(local.aws_resource_name_prefix,0,28), "lb"])
  load_balancer_type         = local.load_balancer_type
  internal                   = var.internal_alb
  subnets                    = local.lb_subnet_ids
  security_groups            = local.lb_security_group_ids
  enable_deletion_protection = var.enable_deletion_protection
  enable_cross_zone_load_balancing  = true
  drop_invalid_header_fields = var.drop_invalid_header
  idle_timeout               = var.idle_timeout
  enable_http2               = var.enable_http2  # Use input variable to enable or disable HTTP/2
  tags = merge(
    {
      "Name" = local.aws_resource_name_prefix
    },
    local.default_resource_tags
  )
}
output "aws_lb_arn" {
  description = "The ARN of the load balancer."
  value       = var.use_load_balancer ? aws_lb.default[0].arn : ""
}
output "aws_lb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = var.use_load_balancer ? aws_lb.default[0].dns_name : ""
}
