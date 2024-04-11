# Forward action

resource "random_integer" "priority1" {
  min = 1
  max = 10
  keepers = {
    # Generate a new integer each time we switch to a new port
    port = var.service_port
  }
}


resource "aws_lb_target_group" "ext_listener_tg_path_based" {
  count    = var.use_path_based_listener ? length(var.ext_listener_arn_path_based) : 0
  name     = join("-", [substr(local.aws_resource_name_prefix,0,28), random_integer.priority1.result])
  vpc_id   = data.aws_vpc.default_vpc.id
  port     = random_integer.priority1.keepers.port
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


resource "aws_lb_listener_rule" "path_based_routing" {
  count    = var.use_path_based_listener ? length(var.ext_listener_arn_path_based) : 0
  listener_arn = var.ext_listener_arn_path_based[count.index]
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ext_listener_tg_path_based[count.index].arn
  }

  condition {
    path_pattern {
      values = var.path_priority_map.app_path_list
    }
  }
  priority = var.path_priority_map.priority
}

output "ext_lb_tg_path_based_arn" {
  value = [ for tg in aws_lb_target_group.ext_listener_tg_path_based: tg.arn ]
}
