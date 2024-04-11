resource "aws_cloudwatch_metric_alarm" "out" {
  count               = var.use_autoscaling_group && local.use_policy_scale_out ? 1 : 0
  alarm_name          = join("-", [local.aws_resource_name_prefix, "alarm-out"])
  comparison_operator = lookup(var.asg_metric_alarm_out, "comparison_operator", "GreaterThanOrEqualToThreshold")
  evaluation_periods  = lookup(var.asg_metric_alarm_out, "evaluation_periods", "2")
  metric_name         = lookup(var.asg_metric_alarm_out, "metric_name", "CPUUtilization")
  namespace           = lookup(var.asg_metric_alarm_out, "namespace", "AWS/EC2")
  period              = lookup(var.asg_metric_alarm_out, "period", "120")
  statistic           = lookup(var.asg_metric_alarm_out, "statistic", "Average")
  threshold           = lookup(var.asg_metric_alarm_out, "threshold", "80")

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.default[0].name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.out[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "in" {
  count               = var.use_autoscaling_group && local.use_policy_scale_in ? 1 : 0
  alarm_name          = join("-", [local.aws_resource_name_prefix, "alarm-in"])
  comparison_operator = lookup(var.asg_metric_alarm_in, "comparison_operator", "LessThanOrEqualToThreshold")
  evaluation_periods  = lookup(var.asg_metric_alarm_in, "evaluation_periods", "2")
  metric_name         = lookup(var.asg_metric_alarm_in, "metric_name", "CPUUtilization")
  namespace           = lookup(var.asg_metric_alarm_in, "namespace", "AWS/EC2")
  period              = lookup(var.asg_metric_alarm_in, "period", "120")
  statistic           = lookup(var.asg_metric_alarm_in, "statistic", "Average")
  threshold           = lookup(var.asg_metric_alarm_in, "threshold", "40")

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.default[0].name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.in[0].arn]
}
