resource "aws_lb_target_group" "default" {
  for_each = local.lb_listeners_iterable
  name     = join("-", [substr(local.aws_resource_name_prefix,0,28), length(each.key)])
  vpc_id   = data.aws_vpc.default_vpc.id
  port     = lookup(each.value, "backend_service_port", each.value.service_port)
  protocol = lookup(each.value, "backend_service_protocol", each.value.service_protocol)
  preserve_client_ip = local.set_preserve_client_ip
  
  target_type = var.target_type
  dynamic stickiness  {
    for_each = local.is_stickiness_provided
    content {
      enabled = var.allow_stickiness
      type = local.lb_stickiness_type
    }
  }


  dynamic "health_check" {
    for_each = local.is_health_check_provided
    content {
      enabled             = lookup(local.health_check, "enabled", null)
      healthy_threshold   = lookup(local.health_check, "healthy_threshold", null)
      interval            = lookup(local.health_check, "interval", null)
      path                = lookup(local.health_check, "path", null)
      port                = lookup(local.health_check, "port", null)
      protocol            = lookup(local.health_check, "protocol", null)
      unhealthy_threshold = lookup(local.health_check, "unhealthy_threshold", null)
      matcher             = lookup(local.health_check, "matcher", null)
      timeout             = lookup(local.health_check, "timeout", null)
    }
  }
}

output "lb_target_group_arn" {
  value = [ for tg in aws_lb_target_group.default: tg.arn ]
}
