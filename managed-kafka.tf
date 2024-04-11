resource "aws_cloudwatch_log_group" "default" {
  count             = var.create_msk_cluster ? 1 : 0
  name              = join("-", [local.aws_resource_name_prefix, "log-group"])
  retention_in_days = var.days_to_retain_logs
  tags = merge(
    local.default_resource_tags,
    { Name = join("-", [local.aws_resource_name_prefix, "msk"]) }
  )
}

resource "aws_msk_cluster" "default" {
  count                  = var.create_msk_cluster ? 1 : 0
  cluster_name           = join("-", [local.aws_resource_name_prefix, "msk"])
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.node_count
  enhanced_monitoring    = var.monitoring_level

  broker_node_group_info {
    instance_type   = var.node_instance_type
    storage_info {
      ebs_storage_info {
        volume_size = var.node_storage_size
      }
    }
    client_subnets  = length(var.deployment_subnet_ids) == 0 ? data.aws_subnets.vpc_subnets_targeted.ids : var.deployment_subnet_ids
    security_groups = [aws_security_group.stack-sg.id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.in_transit_encryption == null ? "TLS" : var.in_transit_encryption
      in_cluster    = var.is_node_communication_encrypted ? var.is_node_communication_encrypted : true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.default[count.index].name
      }
    }
  }
  tags = merge(
    local.default_resource_tags,
    { Name = join("-", [local.aws_resource_name_prefix, "msk"]) }
  )
}

# OUTPUTS

output "msk_cluster_arn" {
  value = var.create_msk_cluster ? aws_msk_cluster.default[0].arn : ""
}

output "zookeeper_connect_string" {
  value = var.create_msk_cluster ? aws_msk_cluster.default[0].zookeeper_connect_string : ""
}
output "bootstrap_brokers" {
  value = var.create_msk_cluster && var.in_transit_encryption == null ? aws_msk_cluster.default[0].bootstrap_brokers_tls : var.create_msk_cluster && var.in_transit_encryption != null ? aws_msk_cluster.default[0].bootstrap_brokers : ""
}
