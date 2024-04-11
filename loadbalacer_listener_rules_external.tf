# Forward action

resource "random_integer" "priority" {
  min = 1
  max = 10
  keepers = {
    # Generate a new integer each time we switch to a new listener ARN
    port = var.service_port
  }
}


resource "aws_lb_target_group" "external_listener_tg" {
  count    = var.use_external_load_balancer_listner ? 1 : 0
  name     = join("-", [substr(local.aws_resource_name_prefix,0,28), random_integer.priority.result])
  vpc_id   = data.aws_vpc.default_vpc.id
  port     = random_integer.priority.keepers.port
  protocol = var.service_protocol
  stickiness  {
        enabled = var.allow_stickiness
        type = local.lb_stickiness_type
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
 lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb_listener_rule" "host_based_routing" {
  count    = var.use_external_load_balancer_listner ? 1 : 0
  listener_arn =var.external_listener_arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_listener_tg[0].arn
  }

  condition {
    host_header {
      values = [var.external_listener_host]
    }
  }
}

output "ext_lb_target_group_arn" {
  value = [ for tg in aws_lb_target_group.external_listener_tg: tg.arn ]
}
