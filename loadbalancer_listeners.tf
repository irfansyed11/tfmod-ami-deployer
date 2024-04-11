resource "aws_lb_listener" "default" {
  for_each          = local.lb_listeners_iterable
  load_balancer_arn = var.external_load_balancer == null ? aws_lb.default[0].arn : data.aws_lb.default[0].id
  protocol          = each.value.service_protocol
  port              = each.value.service_port
  certificate_arn   = lookup(each.value, "certificate_arn", null)
  ssl_policy        = lookup(each.value, "ssl_policy", null)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default[each.key].arn
  }
}

output "lb_listener_arn" {
  value = [ for lb in aws_lb_listener.default: lb.arn ]
}

resource "aws_lb_listener_certificate" "extra_certificate" {
  count  = "${var.additional_lb_certificate}" ? 1 : 0
  listener_arn    = aws_lb_listener.default["https-tcp"].arn
  certificate_arn  = nonsensitive(data.aws_ssm_parameter.aws_acm_certificate_arn.value)
}
