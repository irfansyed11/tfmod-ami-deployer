locals {
  tgs = (var.ext_tg == null ? (!var.use_path_based_listener ? (!var.use_external_load_balancer_listner ? [for tg in values(aws_lb_target_group.default) : tg.arn] : [aws_lb_target_group.external_listener_tg[0].arn]) : [for tg in aws_lb_target_group.ext_listener_tg_path_based : tg.arn]) : [var.ext_tg])
  # tst = aws_autoscaling_group.default[0].id
}

resource "aws_autoscaling_group" "default" {
  count               = var.use_autoscaling_group ? 1 : 0
  name                = join("-", [local.aws_resource_name_prefix, "asg"])
  desired_capacity    = var.service_capacity
  max_size            = var.service_max_size
  min_size            = var.service_min_size
  vpc_zone_identifier = local.deployment_subnet_ids
  # target_group_arns         = var.ext_tg == null?!var.use_external_load_balancer_listner?[for tg in values(aws_lb_target_group.default) : tg.arn]: [aws_lb_target_group.external_listener_tg[0].arn]: [var.ext_tg]
  # target_group_arns         = (var.ext_tg == null ? (!var.use_path_based_listener ? (!var.use_external_load_balancer_listner ? [for tg in values(aws_lb_target_group.default) : tg.arn] : [aws_lb_target_group.external_listener_tg[0].arn]) : [for tg in aws_lb_target_group.ext_listener_tg_path_based : tg.arn]) : [var.ext_tg])
  health_check_type         = var.health_check_type
  health_check_grace_period = var.service_health_check_wait

  launch_template {
    name    = aws_launch_template.default[count.index].name
    version = aws_launch_template.default[count.index].latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
  dynamic "initial_lifecycle_hook" {
    for_each = local.enable_launch_hook
    content {
      name                 = join("-", [local.aws_resource_name_prefix, "lh"])
      default_result       = "ABANDON"
      heartbeat_timeout    = 600
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"

      notification_metadata = <<-EOF
        {
          "leader-strategy": "${local.normalized_leader_strategy}"
        }
      EOF
    }
  }
  # tags = merge(
  #   { "Name" = join("-", [local.aws_resource_name_prefix, "asg"]) },
  #   local.default_instance_tags,
  #   module.aws_tagger.tags.ec2,
  #   { "apps" = join(", ", var.apps) }
  # )
  tag {
    key                 = "DesiredCapacity"
    value               = var.service_capacity
    propagate_at_launch = false
  }

  tag {
    key                 = "MinCapacity"
    value               = var.service_min_size
    propagate_at_launch = false
  }

  tag {
    key                 = "MaxCapacity"
    value               = var.service_max_size
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_attachment" "default" {
  count = var.use_autoscaling_group ? length(local.tgs) : 0

  autoscaling_group_name = aws_autoscaling_group.default[0].id
  lb_target_group_arn    = local.tgs[count.index]
}

resource "aws_autoscaling_lifecycle_hook" "termination" {
  count                  = var.instance_termination_handler != null && var.use_autoscaling_group ? 1 : 0
  name                   = join("-", [local.aws_resource_name_prefix, "termination-hook"])
  autoscaling_group_name = aws_autoscaling_group.default[0].name
  default_result         = "ABANDON"
  heartbeat_timeout      = 600
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_metadata = <<-EOF
    {
      "termination-handler": "${var.instance_termination_handler}",
      "mongo-connection-key": "${var.mongo_secret_name}",
      "mongo-uri-key": "${var.mongo_secret_key}"
    }
  EOF
}

resource "aws_autoscaling_policy" "out" {
  count                  = var.use_autoscaling_group && local.use_policy_scale_out ? 1 : 0
  name                   = join("-", [local.aws_resource_name_prefix, "policy-out"])
  scaling_adjustment     = lookup(var.asg_policy_out, "scaling_adjustment", null)
  adjustment_type        = "ChangeInCapacity"
  cooldown               = lookup(var.asg_policy_out, "cooldown", null)
  autoscaling_group_name = aws_autoscaling_group.default[0].name
}

resource "aws_autoscaling_policy" "in" {
  count                  = var.use_autoscaling_group && local.use_policy_scale_in ? 1 : 0
  name                   = join("-", [local.aws_resource_name_prefix, "policy-in"])
  scaling_adjustment     = lookup(var.asg_policy_in, "scaling_adjustment", null)
  adjustment_type        = "ChangeInCapacity"
  cooldown               = lookup(var.asg_policy_in, "cooldown", null)
  autoscaling_group_name = aws_autoscaling_group.default[0].name
}

resource "aws_launch_template" "default" {
  count                  = var.use_autoscaling_group ? 1 : 0
  name                   = join("-", [local.aws_resource_name_prefix, "launch-template"])
  image_id               = local.initial_deployment_ami_id
  instance_type          = local.deployment_instance_type
  vpc_security_group_ids = [aws_security_group.stack-sg.id]
  key_name               = var.deployment_key_pair_name
  user_data              = local.user_data
  iam_instance_profile {
    name = var.instance_iam_profile != null ? var.instance_iam_profile : aws_iam_instance_profile.ec2_iam_profile[0].name
  }

  dynamic "block_device_mappings" {
    for_each = var.instance_extra_disks
    iterator = device
    content {
      device_name = device.value.device_name
      ebs {
        delete_on_termination = lookup(device.value, "delete_on_termination", true)
        encrypted             = true
        iops                  = lookup(device.value, "iops", null)
        throughput            = lookup(device.value, "throughput", null)
        snapshot_id           = lookup(device.value, "snapshot_id", null)
        volume_size           = lookup(device.value, "volume_size", null)
        volume_type           = lookup(device.value, "volume_type", null)
      }
    }
  }

  # block_device_mappings {
  #   device_name = "/dev/sda1"

  #   ebs {
  #     encrypted             = true
  #   }
  # }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      { "Name" = join("-", [local.aws_resource_name_prefix, "asg"]) },
      local.default_instance_tags,
      module.aws_tagger.tags.ec2
    )
  }

  tags = var.use_autoscaling_group ? merge(
    { TargetAutoScalingGroup = join("-", [local.aws_resource_name_prefix, "asg"]) },
    local.default_resource_tags,
  ) : local.default_resource_tags
}

output "tg_attachment_to_asg" {
  value = var.use_autoscaling_group ? aws_autoscaling_group.default[0].target_group_arns : []
}

output "asg" {
  value = var.use_autoscaling_group ? aws_autoscaling_group.default : null
}
