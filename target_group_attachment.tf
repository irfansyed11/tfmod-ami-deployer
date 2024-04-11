resource "aws_lb_target_group_attachment" "default" {
  for_each         = local.instance_target_group_attachments
  target_group_arn = each.value.target_group.arn
  target_id        = each.value.instance.id
  port             = each.value.target_group.port
}
