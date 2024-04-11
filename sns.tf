resource "time_static" "main" {}

resource "null_resource" "sns_publisher" {
  for_each = local.sns_messages

  provisioner "local-exec" {
    command = <<EOF
      aws sns publish \
        --topic-arn arn:aws:sns:${data.aws_region.region.name}:${local.tools_account_id}:ami-deployer-usw2-lambda-crud-topic \
        --message '${each.value}' \
        --region ${data.aws_region.region.name}
    EOF
  }

  triggers = {
    timestamp = timestamp() # This trigger enforces the null resource to run every apply
  }
}
