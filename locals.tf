locals {
  # Validations
  validate_protocol_condition        = var.load_balancer_type == "network" ? contains(["TCP", "TLS", "UDP", "TCP_UDP"], var.service_protocol) : contains(["HTTP", "HTTPS"], var.service_protocol)
  validate_protocol_error_message    = "The service protocol specified is not supported by the selected load balancer."
  validate_protocol_check            = regex("^${local.validate_protocol_error_message}$", (local.validate_protocol_condition || !var.use_load_balancer ? local.validate_protocol_error_message : ""))
  validate_instance_ip_condition     = length(var.instance_ips) == 0 || length(var.instance_ips) >= var.service_capacity
  validate_instance_ip_error_message = "Each EC2 instance must be provided an IP address. There are ${var.service_capacity} instances and ${length(var.instance_ips)} IP addresses."
  validate_instance_ip_check         = regex("^${local.validate_instance_ip_error_message}$", (local.validate_instance_ip_condition || var.use_autoscaling_group ? local.validate_instance_ip_error_message : ""))
  user_data                          = try(base64encode(var.bootstrap_script_inline), filebase64("${path.root}/${var.bootstrap_script_file}"), null)
  default_instance_tags              = merge(var.tags_template, var.instance_tags_template)
  default_resource_tags              = merge(var.tags_template, module.aws_tagger.tags.generic)
  environment                        = trim(local.sub_env,substr(local.sub_env, -2,-1 ))
  #aws_resource_name_prefix           = substr(replace(var.deployment_name, "_", "-"), 0, 28)
  aws_resource_name_prefix           = replace(var.deployment_name, "_", "-")
  # EC2 Instances
  deployment_instance_type  = var.deployment_instance_type == null ? (local.environment == "dev" ? "t3a.medium" : (local.environment == "stage" ? "t3a.large" : (local.environment == "prod" ? "m5.large" : "t3a.medium"))) : var.deployment_instance_type
  initial_deployment_ami_id = (var.ec2_image_builder && var.initial_deployment_ami_id == null) ? data.aws_ssm_parameter.ami_id[0].value : var.initial_deployment_ami_id

  # Load Balancer Options
  lb_security_group_ids = (var.load_balancer_type == "network" && var.disable_nw_sg == true)? null : (var.load_balancer_security_group_ids == null ? (var.app_in_ports == null ? null : [aws_security_group.stack-sg.id]) : var.load_balancer_security_group_ids)
  lb_subnet_ids         = length(var.elb_subnet_ids) == 0 ? data.aws_subnets.vpc_subnets_targeted.ids : var.elb_subnet_ids
  deployment_subnet_ids = length(var.deployment_subnet_ids) == 0 ? data.aws_subnets.vpc_subnets.ids : var.deployment_subnet_ids
  load_balancer_type    = var.load_balancer_type == null ? "application" : var.load_balancer_type

  use_default_listener       = local.load_balancer_listeners == null || length(local.load_balancer_listeners) == 0
  use_external_load_balancer = var.external_load_balancer == null ? false : true
  #use_default_listener       = var.load_balancer_listeners == null || length(var.load_balancer_listeners) == 0

  default_listener = {
    default = {
      service_vpc_id           = data.aws_vpc.default_vpc.id
      service_protocol         = var.service_protocol
      service_port             = var.service_port
      backend_service_protocol = var.backend_service_protocol != null ? var.backend_service_protocol : var.service_protocol
      backend_service_port     = var.backend_service_port != null ? var.backend_service_port : var.service_port
      certificate_arn          = var.service_protocol == "HTTPS" ? ( var.dns_check == "allegiantair.com" ? data.aws_ssm_parameter.aws_acm_certificate_arn_allegiantair[0].value : data.aws_ssm_parameter.aws_acm_certificate_arn.value) : null
      ssl_policy               = var.service_protocol == "HTTPS" ? var.elb_listener_ssl_policy: null
    }
  }
  lb_listeners = var.use_load_balancer || local.use_external_load_balancer ? (local.use_default_listener ? local.default_listener : local.load_balancer_listeners) : null
  lb_redirect_listeners = var.use_redirect_listener ? local.load_balancer_redirect_listener : null
  lb_listeners_iterable  = local.lb_listeners == null ? {} : local.lb_listeners
  lb_redirect_listeners_iterable  = local.lb_redirect_listeners == null ? {} : local.lb_redirect_listeners

  https_listener = var.ssl_service_port == null ? null : {
    https-tcp = {
      service_vpc_id   = "${data.aws_vpc.default_vpc.id}"
      service_protocol = "HTTPS"
      service_port     = var.ssl_service_port
      ssl_policy       = var.elb_listener_ssl_policy
      certificate_arn  = var.dns_check == "allegiantair.com" ? data.aws_ssm_parameter.aws_acm_certificate_arn_allegiantair[0].value : data.aws_ssm_parameter.aws_acm_certificate_arn.value
    }
  }
  http_listener = var.http_service_port == null ? null : {
    http-tcp = {
      service_vpc_id   = "${data.aws_vpc.default_vpc.id}"
      service_protocol = "HTTP"
      service_port     = var.http_service_port
    }
  }

  check_user_https_listner = contains(keys(var.load_balancer_listeners), "https-tcp")?(length(keys(var.load_balancer_listeners.https-tcp)) == 0? false: true): true
  check_user_http_listner = contains(keys(var.load_balancer_listeners), "http-tcp")?(length(keys(var.load_balancer_listeners.http-tcp)) == 0? false: true): true
  load_balancer_listeners = local.check_user_https_listner|| local.check_user_http_listner? var.load_balancer_listeners: (merge(local.http_listener, local.https_listener))
  load_balancer_redirect_listener = var.use_redirect_listener ? var.load_balancer_redirect_listener : null

  is_stickiness_provided = var.lb_stickiness_type == "NA"? []: [true]
  lb_stickiness_type = var.lb_stickiness_type == null ? var.load_balancer_type == "network" ? "source_ip": "lb_cookie": var.lb_stickiness_type
  lb_default_action_type = var.load_balancer_type == "network" ? "forward" : "redirect"

  # Health check setup if health_check_type is set to ELB and elb_health_check is provided
  default_elb_health_check = {
    enabled             = var.health_check_enabled
    healthy_threshold   = var.health_check_up_tresh
    interval            = var.health_check_interval
    path                = var.health_check_path
    port                = var.backend_service_port != null ? var.backend_service_port : var.service_port
    protocol            = var.backend_service_protocol != null ? var.backend_service_protocol : var.service_protocol
    unhealthy_threshold = var.health_check_down_thresh
  }
  default_alb_health_check = {
    matcher = var.health_check_ret_vals
    timeout = var.health_check_timeout
  }
  default_nlb_health_check = {
    matcher = "200-399"
    timeout = var.health_check_timeout
  }
  health_check_type          = var.health_check_type == null ? (var.use_load_balancer || local.use_external_load_balancer ? "ELB" : "EC2") : var.health_check_type
  is_health_check_provided   = (local.health_check_type == "EC2" || local.health_check_type == "ELB"||local.health_check_type == "TCP") && (length(var.elb_health_check) > 0 || length(local.default_elb_health_check) > 0) ? [true] : []
  health_check               = length(local.is_health_check_provided) > 0 && var.load_balancer_type == "application" ? merge(local.default_elb_health_check, local.default_alb_health_check, var.elb_health_check) : var.elb_health_check
  normalized_leader_strategy = var.leader_election_strategy == null ? null : lower(var.leader_election_strategy)
  enable_launch_hook         = var.leader_election_strategy == null || !var.use_autoscaling_group ? [] : [true]

  # If we're not using an autoscaling group generate the information needed
  ec2_instance_names                = var.use_ec2_instaces ? toset(formatlist("%s", range(var.service_capacity))) : []
  ec2_instance_names_and_ip_map     = var.use_ec2_instaces ? { for i, e in local.ec2_instance_names : "${e}" => { ip = try(lookup(var.instance_ips[i], "ip", null), null), subnet_id = try(lookup(var.instance_ips[i], "subnet_id", null), null) } } : {}
  instance_target_group_attachments = ( var.use_load_balancer || var.longlived_with_ext_loadbalancer ) && var.use_ec2_instaces ? { for p in setproduct(keys(aws_lb_target_group.default), local.ec2_instance_names) : "${p[0]}-${p[1]}" => { target_group = aws_lb_target_group.default[p[0]], instance = aws_instance.default[p[1]] } } : {}
  set_preserve_client_ip = var.load_balancer_type == "network" ? var.preserve_client_ip : null

  # Auto Scaling Policies
  use_policy_scale_in  = var.use_autoscaling_group && var.asg_policy_in != null
  use_policy_scale_out = var.use_autoscaling_group && var.asg_policy_out != null
  sub_env              = data.aws_ssm_parameter.sub_env.value
  ou_logical_name      = data.aws_ssm_parameter.ou_logical_name.value
  account_name         = data.aws_ssm_parameter.account_name.value
  today                = timestamp()
  ami_expiration_date  = formatdate("MM-DD-YYYY", timeadd(local.today, "8640h"))
  data_classification  = can(regex("standard", local.ou_logical_name)) ? "standard" : can(regex("confidential", local.ou_logical_name)) ? "confidential" : can(regex("internal", local.ou_logical_name)) ? "pci_internal" : can(regex("external", local.ou_logical_name)) ? "pci_external" : "unknown"
  stack_role            = var.stack_role == null ? split("-",lower(local.account_name))[3] == "${local.sub_env}app" ? "middleware" : split("-",lower(local.account_name))[3] == "${local.sub_env}web" ? "web" : "db" : var.stack_role
  aws_subnet_az        = data.aws_subnet.vpc_subnet_az_info.*.availability_zone
  parameter_group_name = var.parameter_group_name == null ? "default.memcached1.4" : var.parameter_group_name

  # DNS RECORD FOR https://github.com/terraform-aws-modules/terraform-aws-route53
  #dns_records = var.dns_cnames == null ? null : values({ for cn in var.dns_cnames : cn => { name = cn, type = "CNAME", ttl = 60, records = [aws_lb.default[0].dns_name, ] } })

  # SNS Message
  sns_messages  = var.use_autoscaling_group ? {for x in var.apps : x => jsonencode({
    app_sub-environment            = "${x}|${local.sub_env}"
    timestamp                      = local.today
    creation-time                  = time_static.main.rfc3339
    ami                            = local.initial_deployment_ami_id
    apps                           = var.apps
    ou                             = local.ou_logical_name
    sub-environment                = local.sub_env
    environment                    = local.environment
    app-bundle                     = var.deployment_name
    app-bundle-asg                 = aws_autoscaling_group.default[0].name
    account                        = data.aws_caller_identity.current.account_id
    })
  } : {}
  tools_account_id = data.aws_ssm_parameter.control_tower_environment.value == "dev-control-tower" ? "784671907590" : data.aws_ssm_parameter.control_tower_environment.value == "prod-control-tower" ? "889690428152" : null
}
