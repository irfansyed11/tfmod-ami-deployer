resource "aws_elasticache_cluster" "elasticache_cluster" {
  count                        = var.use_elasticcache_cluster ? 1 : 0
  cluster_id                   = "${local.aws_resource_name_prefix}-ecc"
  engine                       = var.ec_engine
  node_type                    = var.ec_node_type
  num_cache_nodes              = length(local.deployment_subnet_ids)
  parameter_group_name         = local.parameter_group_name
  preferred_availability_zones = local.aws_subnet_az
  subnet_group_name            = aws_elasticache_subnet_group.elasticache-memcached-subnet[0].name
  security_group_ids           = [aws_security_group.stack-sg.id]
  port                         = var.ec_port
  tags = merge(
    local.default_resource_tags,
    { Name = join("-", [local.aws_resource_name_prefix, "ecc"]) }
  )
}

# resource "aws_route53_record" "dns_cnames" {
#   zone_id = local.route53_zone_id
#   count   = length(local.dns_cnames)
#   name    = "${local.dns_cnames}.${local.dns_zone}"
#   type    = "CNAME"
#   ttl     = "300"
#   records = [aws_elasticache_cluster.elasticache_cluster.cluster_address]
# }

resource "aws_elasticache_subnet_group" "elasticache-memcached-subnet" {
  count      = var.use_elasticcache_cluster ? 1 : 0
  name       = "${local.aws_resource_name_prefix}-subnet"
  subnet_ids = local.deployment_subnet_ids
  tags = merge(
    local.default_resource_tags,
    { Name = join("-", [local.aws_resource_name_prefix, "ecc"]) }
  )
}

output "elastic_cache_cluster_addr" {
  value = var.use_elasticcache_cluster ? aws_elasticache_cluster.elasticache_cluster[0].cluster_address : ""
}
