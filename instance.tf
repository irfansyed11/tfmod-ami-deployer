resource "aws_instance" "default" {
  for_each               = local.ec2_instance_names_and_ip_map
  subnet_id              = lookup(each.value, "subnet_id", null)
  private_ip             = lookup(each.value, "ip", null)
  vpc_security_group_ids = [aws_security_group.stack-sg.id]
  instance_type          = var.deployment_instance_type
  ami                    = local.initial_deployment_ami_id
  key_name               = var.deployment_key_pair_name
  iam_instance_profile   = var.instance_iam_profile != null ? var.instance_iam_profile : aws_iam_instance_profile.ec2_iam_profile[0].name
  user_data              = local.user_data
  root_block_device {
    encrypted = true
  }
  dynamic "ebs_block_device" {
    for_each = var.instance_extra_disks
    iterator = device
    content {
      delete_on_termination = lookup(device.value, "delete_on_termination", true)
      device_name           = lookup(device.value, "device_name", null)
      encrypted             = true
      iops                  = lookup(device.value, "iops", null)
      throughput            = lookup(device.value, "throughput", null)
      snapshot_id           = lookup(device.value, "snapshot_id", null)
      volume_size           = lookup(device.value, "volume_size", null)
      volume_type           = lookup(device.value, "volume_type", null)
      tags = merge(
        module.aws_tagger.tags.ec2,
        local.default_instance_tags,
        { "Name" = "${replace(var.deployment_name, "_", "-")}" }
      )
    }
  }
  disable_api_termination = var.enable_termination_protection
  tags = merge(
    local.default_instance_tags,
    module.aws_tagger.tags.ec2,
    { "Name" = "${replace(var.deployment_name, "_", "-")}" },
  )
}
