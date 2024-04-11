
resource "aws_iam_role_policy_attachment" "ec2_iam_role_ssm_access" {
  count      = ((var.use_autoscaling_group || var.use_ec2_instaces) && var.instance_iam_profile == null) ? 1 : 0
  role       = aws_iam_role.ec2_iam_role[0].name
  policy_arn = data.aws_iam_policy.read_ssm.arn
}

resource "aws_iam_role_policy_attachment" "ec2_iam_role_ssm_core" {
  count = ((var.use_autoscaling_group || var.use_ec2_instaces) && var.instance_iam_profile == null) ? 1 : 0
  role       = aws_iam_role.ec2_iam_role[0].name
  policy_arn = data.aws_iam_policy.core_ssm.arn
}
resource "aws_iam_instance_profile" "ec2_iam_profile" {
  count = ((var.use_autoscaling_group || var.use_ec2_instaces) && var.instance_iam_profile == null) ? 1 : 0
  name  = join("-", [local.aws_resource_name_prefix, "ec2-iam-profile"])
  role  = aws_iam_role.ec2_iam_role[0].name
}

resource "aws_iam_role" "ec2_iam_role" {
  count = ((var.use_autoscaling_group || var.use_ec2_instaces) && var.instance_iam_profile == null) ? 1 : 0
  name  = join("-", [local.aws_resource_name_prefix, "ec2-role"])
  tags = merge(
    {
      "Name" = local.aws_resource_name_prefix
    },
    local.default_resource_tags
  )
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_role_policy" "inline_policy" {
  count = var.inline_policy != "" ? 1 : 0

  name   = "inline-policy"
  role   = aws_iam_role.ec2_iam_role[0].name
  policy = var.inline_policy
}

resource "aws_iam_role_policy_attachment" "custom" {
  count = length(var.managed_policies)

  role       = aws_iam_role.ec2_iam_role[0].name
  policy_arn = var.managed_policies[count.index]
}
output "ec2_iam_role_name" {
  value = ((var.use_autoscaling_group || var.use_ec2_instaces) && var.instance_iam_profile == null) ? aws_iam_role.ec2_iam_role[0].name : ""
}
