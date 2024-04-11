locals {
  unique_load_balancers                = distinct([for lb in var.external_lb_path_based_routing : lb.load_balancer_name])
  convert_unique_load_balancers_to_map = { for lb in local.unique_load_balancers : lb => lb }
}

data "aws_lb" "path_based_lb" {
  for_each = local.convert_unique_load_balancers_to_map

  name = each.value
}

resource "random_integer" "path_based_priority" {
  for_each = var.external_lb_path_based_routing

  min = 1
  max = 10
  keepers = {
    # Generate a new integer each time we switch to a new listener ARN
    port = var.service_port
  }
}

resource "aws_lb_target_group" "path_based_tg" {
  for_each = var.external_lb_path_based_routing

  name     = join("-", [substr(each.key, 0, 28), random_integer.path_based_priority[each.key].result])
  vpc_id   = data.aws_vpc.default_vpc.id
  port     = random_integer.path_based_priority[each.key].keepers.port
  protocol = var.service_protocol
  stickiness {
    enabled = var.allow_stickiness
    type    = local.lb_stickiness_type
  }
  dynamic "health_check" {
    for_each = local.is_health_check_provided

    content {
      enabled             = lookup(local.health_check, "enabled", null)
      healthy_threshold   = lookup(local.health_check, "healthy_threshold", null)
      interval            = lookup(local.health_check, "interval", null)
      path                = lookup(var.external_lb_path_based_routing[each.key].health_check, "path", null)
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

resource "aws_lb_listener_rule" "path_based_routing_http" {
  for_each = { for k, v in var.external_lb_path_based_routing : k => v
  if coalesce(var.http_service_port, "[null]") != "[null]" }

  listener_arn = aws_lb_listener.listener_http[each.value.load_balancer_name].arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.path_based_tg[each.key].arn
  }
  # condition { # Disable until we get proper host headers set in applications
  #   host_header {
  #     values = [var.external_listener_host]
  #   }
  # }
  condition {
    path_pattern {
      values = [each.value.routing.path]
    }
  }
}

resource "aws_lb_listener_rule" "path_based_routing_https" {
  for_each = var.external_lb_path_based_routing

  listener_arn = aws_lb_listener.listener_https[each.value.load_balancer_name].arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.path_based_tg[each.key].arn
  }
  # condition { # Disable until we get proper host headers set in applications
  #   host_header {
  #     values = [var.external_listener_host]
  #   }
  # }
  condition {
    path_pattern {
      values = [each.value.routing.path]
    }
  }
}

resource "aws_lb_listener" "listener_http" {
  for_each = { for load_balancer in local.convert_unique_load_balancers_to_map : load_balancer => {}
  if coalesce(var.http_service_port, "[null]") != "[null]" }

  load_balancer_arn = data.aws_lb.path_based_lb[each.key].arn
  port              = var.http_service_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "502"
    }
  }
}

resource "aws_lb_listener" "listener_https" {
  for_each = local.convert_unique_load_balancers_to_map

  load_balancer_arn = data.aws_lb.path_based_lb[each.key].arn
  port              = var.ssl_service_port
  protocol          = "HTTPS"
  ssl_policy        = var.elb_listener_ssl_policy
  certificate_arn   = var.dns_check == "allegiantair.com" ? data.aws_ssm_parameter.aws_acm_certificate_arn_allegiantair[0].value : data.aws_ssm_parameter.aws_acm_certificate_arn.value

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "502"
    }
  }
}

resource "aws_lb_listener_certificate" "extra_certificate_path_based" {
  for_each = { for load_balancer in local.convert_unique_load_balancers_to_map : load_balancer => {}
  if var.additional_lb_certificate }

  # listener_arn    = aws_lb_listener.listener_https[each.value.id].arn
  listener_arn    = aws_lb_listener.listener_https[each.key].arn
  certificate_arn = nonsensitive(data.aws_ssm_parameter.aws_acm_certificate_arn.value)
}

# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "example" {
  depends_on = [aws_autoscaling_group.default]
  for_each   = var.external_lb_path_based_routing

  autoscaling_group_name = aws_autoscaling_group.default[0].id
  lb_target_group_arn    = aws_lb_target_group.path_based_tg[each.key].arn
}

output "path_based_tg_arns" {
  value = [for tg in aws_lb_target_group.external_listener_tg : tg.arn]
}
