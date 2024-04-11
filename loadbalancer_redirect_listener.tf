resource "aws_lb_listener" "default_redirect" {
  for_each          = local.lb_redirect_listeners_iterable
  load_balancer_arn = var.external_load_balancer == null ? aws_lb.default[0].arn : data.aws_lb.default[0].id
  protocol          = each.value.service_protocol
  port              = each.value.service_port
  certificate_arn   = lookup(each.value, "certificate_arn", null)
  ssl_policy        = lookup(each.value, "ssl_policy", null)

  default_action {
    type             = "redirect"

    redirect {
      protocol         = var.redirect_protocol
      port             = var.redirect_port
      status_code      = var.redirect_status_code
    }
  }
}

output "lb_redirect_listener_arn" {
  value = [for lb in aws_lb_listener.default_redirect : lb.arn]
}
