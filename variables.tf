variable "deployment_name" {
  description = "Name of the deployment artifact. Used as a resource prefix."
  type        = string
}

variable "apps" {
  description = "List of applications that make up the application group or application bundle."
  type        = list(any)
  default     = []
}

variable "default_vpc" {
  description = "Name of the default VPC"
  type        = string
  default     = "default-vpc"
}

variable "ec2_image_builder" {
  description = "True, if the AMIs are built using EC2 Image Builder"
  type        = bool
  default     = true
}

variable "deployment_instance_type" {
  description = "The instance type to use for the AMI being deployed"
  type        = string
  default     = null
}

variable "dns_check" {
  description = "dns check either allegiant.com or allegiantair.com"
  type        = string
  default     = "allegiant.com"
}

variable "deployment_subnet_ids" {
  description = "A list of security groups to associate with the deployed EC2 instances"
  type        = list(string)
  default     = []
}

# ------------------------------
#      LoadBalancer Options
# ------------------------------
variable "elb_subnet_ids" {
  description = "A list of security groups to associate with the elb"
  type        = list(string)
  default     = []
}

variable "vpc_subnets_targeted" {
  description = "Targeted subnets of VPC"
  type        = list(string)
  default     = ["main-1", "main-2", "main-3"]
}

variable "use_load_balancer" {
  description = "Indicates if the deployment should be fronted by a load balancer"
  type        = bool
  default     = true
}

variable "use_external_load_balancer_listner" {
  description = "Indicates if the deployment should be fronted by a load balancer"
  type        = bool
  default     = false
}

variable "external_listener_arn" {
  type        = string
  description = "external_listener_arn"
  default     = null
}

variable "external_listener_host" {
  type        = string
  description = "external_listener_host"
  default     = null
}


variable "drop_invalid_header" {
  type        = bool
  description = "Drop isnvalid header - True/False"
  default     = false
}

# Optional Parameter for Load Balancer type, defaults to application in locals
variable "load_balancer_type" {
  description = "Selects whether to use a network or application load balancer. Valid values: network, application."
  type        = string
  default     = null

  validation {
    condition     = var.load_balancer_type == "network" || var.load_balancer_type == "application" || var.load_balancer_type == null
    error_message = "Supported load_balancer_type value is either 'network' or 'application'."
  }
}

variable "ssl_service_port" {
  description = "SSL service port"
  type        = string
  default     = null
}

variable "http_service_port" {
  description = "The (optional) HTTP service port used by the elb listener"
  type        = string
  default     = null
}

variable "health_check_down_thresh" {
  description = "On the ELB, number of consecutive health check fails before marking target unhealthy"
  type        = number
  default     = 5
}

variable "health_check_enabled" {
  description = "Flag to enable ELB health check on target hosts"
  type        = bool
  default     = true
}

variable "preserve_client_ip" {
  description = "Flag to enable/disable preserve client IP"
  type        = bool
  default     = true
}

variable "health_check_interval" {
  description = "ELB health check interval in seconds"
  type        = number
  default     = 50
}

variable "health_check_path" {
  description = "ELB health check path"
  type        = string
  default     = "/"
}

variable "health_check_ret_vals" {
  description = "ELB health check HTTP return value range from target"
  type        = string
  default     = "200-299"
}

variable "health_check_timeout" {
  description = "ELB health check timeout in seconds"
  type        = number
  default     = 30
}

variable "health_check_up_tresh" {
  description = "On the ELB, number of consecutive health check successes before marking target healthy"
  type        = number
  default     = 2
}

variable "load_balancer_security_group_ids" {
  description = "A list of security groups to associate with the load balancer. The default is no security groups."
  type        = list(string)
  default     = null
}

variable "elb_listener_ssl_policy" {
  description = "The AWS ssl policy for cert/key combo used by elb listener(s)"
  type        = string
  default     = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
}

variable "deployment_key_pair_name" {
  description = "The EC2 instance key-pair name to use"
  type        = string
  default     = null
}

variable "use_autoscaling_group" {
  description = "Indicates if the deployed instances should be launched in an autoscaling group"
  type        = bool
  default     = true
}

variable "use_ec2_instaces" {
  description = "Indicates if the deployed instances should be launched in an autoscaling group"
  type        = bool
  default     = false
}

variable "instance_iam_profile" {
  description = "Input iam instance profile name when create outside module."
  type        = string
  default     = null
}
variable "external_load_balancer" {
  description = "Indicates that the template should attach to an external (pre-existing) load balancer instead of creating one. The only accepted value is the full ARN of the load balancer to attach to, otherwise leave value as null."
  type        = string
  default     = null
}

variable "load_balancer_redirect_listener" {
  description = "Each element in the list defines a listener that will be associated with the load balancer. Note a target group for each listener will be created."
  type = map(any)
  default = {}
}

variable "load_balancer_listeners" {
  description = "Each element in the list defines a listener that will be associated with the load balancer. Note a target group for each listener will be created."
  #  service_vpc_id   = string
  #  service_protocol = string
  #  service_port     = number
  #  certificate_arn  = string (Optional)
  #  ssl_policy       = string (Optional)
  type = map(any)
  default = {
    https-tcp = {

    }

    http-tcp = {

    }
  }
}

variable "deployment_security_group_ids" {
  description = "A list of security groups to associate with the deployed EC2 instances"
  type        = list(string)
  default     = null
}

# Termination Protection
variable "enable_deletion_protection" {
  description = "Force deletion of load balancer using management console"
  type        = bool
  default     = false
}

variable "service_port" {
  description = "The port the load balancer will send traffic"
  type        = number
  default     = 80
}

variable "service_protocol" {
  description = "The protocol the load balancer will use when sending traffic"
  type        = string
  default     = "HTTP"
}

variable "backend_service_port" {
  description = "The port the load balancer will send traffic"
  type        = string
  default     = null
}

variable "backend_service_protocol" {
  description = "The protocol the load balancer will use when sending traffic"
  type        = string
  default     = null
}

variable "instance_ips" {
  description = "An object composed of private ip's and their subnets to allocate to instances not launched in an ASG."
  type        = list(map(string))
  default     = []
}

variable "instance_extra_disks" {
  description = "An object composed of maps that describe extra ebs disks"
  type        = map(any)
  default     = {}
}


variable "service_host_name" {
  description = "(Deprecated, use dns_cnames instead).  The traffic hostname that the load balancer will forward"
  type        = string
  default     = "some.host.info"
}

variable "service_capacity" {
  description = "The desired capacity of the autoscaling group managing the deployment instances"
  type        = number
  default     = 1

  validation {
    condition     = var.service_capacity >= 0
    error_message = "The value of service_capacity can not be negative."
  }
}

variable "service_max_size" {
  description = "The max size of the autoscaling group managing the deployment instances"
  type        = number
  default     = 2
}

variable "service_min_size" {
  description = "The min size of the autoscaling group managing the deployment instances"
  type        = number
  default     = 1
}

variable "service_redirect_host" {
  description = "If the load balancer listener rules do not trigger an action the listener redirects to this host"
  type        = string
  default     = null
}

variable "service_health_check_wait" {
  description = "Seconds to wait before health checks are applied to a new instance"
  type        = number
  default     = 180
}

variable "service_redirect_path" {
  description = "If the load balancer listener rules do not trigger an action the listener redirects to 'service_redirect_host + service_redirect_path'"
  type        = string
  default     = null
}

variable "bootstrap_script_inline" {
  description = "The value provided here will be base64 encoded and provided as userdata to the EC2 instance"
  type        = string
  default     = null
}

variable "bootstrap_script_file" {
  description = "Path to a bootstrap script that will base64 encoded and provided as userdata to the EC2 instance. path.root/ is prepended."
  type        = string
  default     = null
}

variable "initial_deployment_ami_id" {
  description = "The initial AMI to use when deploying. Post initial deployment the AMI is managed."
  type        = string
  default     = null
}

variable "health_check_type" {
  description = "The type of health check the autoscaling group will use on the instances"
  type        = string
  default     = "ELB"

  validation {
    condition     = contains(["EC2", "ELB", "TCP"], var.health_check_type)
    error_message = "The valid values for health_check_type is either 'EC2', 'TCP' or 'ELB'."
  }
}

variable "elb_health_check" {
  description = "The ELB health check used if health_check_type is set to ELB. If a health check is not provided the default ELB health check is used."
  type        = map(string)
  default     = {}
}

variable "asg_policy_out" {
  description = "The Simple Scaling Policy to be used when the ASG scales out"
  type        = map(string)
  default     = null
}

variable "asg_policy_in" {
  description = "The Simple Scaling Policy to be used when the ASG scales in"
  type        = map(string)
  default     = null
}

variable "asg_metric_alarm_out" {
  description = "The Simple Scaling Metric Alarm to be used when the ASG scales out"
  type        = map(string)
  default     = {}
}

variable "asg_metric_alarm_in" {
  description = "The Simple Scaling Metric Alarm to be used when the ASG scales in"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to add to created AWS resources"
  type        = map(string)
  default     = {}
}

variable "tags_template" {
  description = "Expected tags for resources"
  type        = map(string)
  default     = {}
}

variable "instance_tags" {
  description = "Optional tags to apply to the deployment EC2 instances. Instance tag template overrides can be provided here."
  type        = map(string)
  default     = {}
}

variable "instance_tags_template" {
  description = "Expected tags for the deployment EC2 instances. Merged with tags_template so tag template overrides can be provided here."
  type        = map(string)
  default     = {}
}

variable "leader_election_strategy" {
  description = <<-EOT
    "Indicates the type of leader election strategy employed on the autoscaling group instances.
    Allowed value: 'simple'. The default is 'null' which means no leader election."
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.leader_election_strategy == null ? true : contains(["simple"], lower(var.leader_election_strategy))
    error_message = "The valid value for leader_election_strategy is 'simple'."
  }
}

variable "instance_termination_handler" {
  description = <<-EOT
    "The termination handler to use on the autoscaling group instances.
    Allowed value: 'mongo'. The default is 'null' which means no termination handling performed."
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.instance_termination_handler == null ? true : contains(["mongo"], lower(var.instance_termination_handler))
    error_message = "The valid value for instance_termination_handler is 'mongo'."
  }
}

variable "mongo_secret_name" {
  description = "The name of the secret in secrets manager that contains the connection uri information"
  type        = string
  default     = ""
}

variable "mongo_secret_key" {
  description = "The key to use to extract connection uri from the mongo secret with the name specified by mongo_secret_name"
  type        = string
  default     = ""
}

# VARIABLES FOR ROUTE 53 MODULE


variable "dns_cnames" {
  description = "List of fqhn for dns cname creation for alb (Optional)."
  type        = list(any)
  default     = []
}

# SECURITY GROUP

variable "app_in_ports" {
  description = "Ingress Ports/CIDRS for Security Group"
  type        = map(any)
  default     = null
}

variable "app_out_ports" {
  description = "Egresss Ports/CIDRS for Security Group"
  type        = map(any)
  default = {
    default_out = {
      desc     = "All ports/ips outbound"
      from     = 0
      to       = 0
      protocol = "-1"
      cidrs    = ["0.0.0.0/0"]
    }
  }
}

# Elastic MemCache variables

variable "ec_engine" {
  type        = string
  description = "engine"
  default     = "memcached"
}

variable "ec_node_type" {
  type        = string
  description = "node type"
  default     = "cache.m4.large"
}

variable "ec_port" {
  type        = number
  description = "Port number for the elastic memcached cluster"
  default     = "11211"
}
variable "ec_dns_name" {
  type        = string
  description = "DNS record name for the elastic memcached cluster"
  default     = "test-ec"
}

variable "use_elasticcache_cluster" {
  description = "Indicates if the elasticcache_cluster should be created."
  type        = bool
  default     = false
}
variable "enable_route53_record" {
  description = "Whether to create DNS records"
  type        = bool
  default     = true
}
variable "parameter_group_name" {
  type        = string
  description = " Parameter group name"
  default     = "default.memcached1.6"
}

# MSK Variables

variable "create_msk_cluster" {
  type        = bool
  description = "Create a MSK Cluser"
  default     = false
}
variable "kafka_version" {
  description = "The version of kafka to run"
  type        = string
  default     = "2.2.1"
}

variable "node_count" {
  description = "Number of broker nodes. Must be a multiple of the number of node subnets."
  type        = number
  default     = 3
}

variable "node_instance_type" {
  description = "The compute to use for each broker node"
  type        = string
  default     = "kafka.m5.large"
}

variable "node_storage_size" {
  description = "The size (GiB) of the EBS volume for each broker node"
  type        = number
  default     = 1000
}

variable "in_transit_encryption" {
  description = "Encryption setting for data in transit"
  type        = string
  default     = null
}

variable "is_node_communication_encrypted" {
  description = "Indicates whether data communication between broker nodes is encrypted"
  type        = bool
  default     = true
}

variable "monitoring_level" {
  description = "Enhanced CloudWatch monitoring level. Valid values: DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, PER_TOPIC_PER_PARTITION."
  type        = string
  default     = "PER_TOPIC_PER_BROKER"
}

variable "days_to_retain_logs" {
  description = "The number of days to retain cloudwatch logs. Values: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653"
  type        = number
  default     = 0
}

# Tagger Variables

variable "ansible_group" {
  description = "Automation Tags, used in Ansible playbook - Ex Val(s): aisap"
  type        = string
  default     = null
}

variable "ansible_groups" {
  description = "Automation Tags, used in Ansible playbook - Ex Val(s): [g4www,combo,cmbap]"
  type        = string
  default     = null
}

variable "backup_schedule" {
  description = "Automation Tags, identifies backups/snapshots schedule - Ex Val(s): 6h|daily|weekly|monthly"
  type        = string
  default     = null
}

variable "build_info" {
  description = "Build Information Tag, We will start with Terraform repo but idea is to later replace it with Build info of the package used for the stack - Ex Val(s): Terraform Repo"
  type        = string
  default     = null
}

variable "business_unit" {
  description = "Business Unit Tag, Ex Val(s): Marketing/Stations/Teesnap"
  type        = string

}

variable "change_ticket" {
  description = "CM Ticket/Release Key Tag, Ex Val(s): CM123455"
  type        = string
  default     = null

}

variable "compliance_status" {
  description = "Compliance Tag, dynamic tag applied by Security Automation - Ex Val(s): compliant/non-compliant"
  type        = string
}

variable "cost_center" {
  description = "Cost Center Tag, Ex Val(s): 459/460/461"
  type        = string
}

variable "domain_name" {
  description = "Domain Information Tag, Ex Val: Digital Customer System/Flight Operations System"
  type        = string
}

variable "ec2_schedule" {
  description = "Automation Tags, used with auto on/off lambdas for cost management - Ex Val(s): las_vegas_office_hours"
  type        = string
  default     = "always-on"
}

variable "feature_version" {
  description = "Feature Version Tag, Version of a specific Feature - Ex Val(s}: v1.5.10"
  type        = string
  default     = null
}

variable "fqdn" {
  description = "FQDN/ALB Name Tag, to identify the FQDN - Ex Val(s): fqdn for the application"
  type        = string
  default     = null
}

variable "initiative_id" {
  description = "Jira Initiative ID Tag, Ex Val(s): san_123435"
  type        = string
}

variable "is_live" {
  description = "Live/Non Live Flag Tag, Ex Val(s): true/false"
  type        = string
  default     = "true"
}


variable "os" {
  description = "Operating System Tag, Ex Val(s): linux|windows"
  type        = string
  default     = "linux"
}

variable "patch_group" {
  description = "Automation Tags, identifiies patch group - Ex Val(s): awstbedpstest_test_dps_tbe_hours"
  type        = string
  default     = null
}

variable "persistent_team_name" {
  description = "Persistent Team Tag, Ex Val(s): partywolves/clouddoctors"
  type        = string
}

variable "stack_name" {
  description = "Stack Name Tag"
  type        = string
}

variable "stack_role" {
  description = "Feature Role Tag, Ex Val(s): web, middleware, db"
  type        = string
  default     = null
}

variable "product_name" {
  description = "Product Information Tag"
  type        = string
}

variable "resource_group" {
  description = "Blue/Green Information Tag to support Blue and Green Stack, Ex Val(s): blue/green"
  type        = string
  default     = "Blue"
}

variable "vertical_name" {
  description = "Vertical Information Tag, Ex Val: Commercial/Airline Ops/Corporate"
  type        = string

}
variable "need_ec2_tags" {
  description = "Do you need EC2 tags? True or False"
  type        = bool
  default     = true
}

variable "ext_tg" {
  description = "External/Existing Target Group for LoadBalancer"
  type        = string
  default     = null
}

variable "allow_stickiness" {
  description = "allow stickiness for NLB"
  type        = bool
  default     = false
}

variable "lb_stickiness_type" {
  description = "Type of lb stickiness e.g NLB -> source_ip , ALB -> lb_cookie or app_cookie"
  type        = string
  default     = null
}

variable "target_type" {
  type        = string
  description = "target_type for Target Group"
  default     = "instance"
}

variable "internal_alb" {
  type        = bool
  description = "Internal ALB True/False"
  default     = true
}

variable "idle_timeout" {
  default     = 60
  type        = string
  description = "The time in seconds that the connection is allowed to be idle."
}

variable "additional_lb_certificate" {
  type    = bool
  default = false
}
variable "inline_policy" {
  description = "IAM Inline Policy (String)"
  type        = string
  default     = ""
}

variable "managed_policies" {
  description = "List of ARNs of IAM policies to attach to main IAM role"
  type        = list(string)
  default     = []
}

variable "use_path_based_listener" {
  description = "Indicates if it requires path based routing or not e.g g4pwa , g4pwa3"
  type        = bool
  default     = false
}

variable "ext_listener_arn_path_based" {
  description = "external load balancer listner for path based routing"
  type        = list(any)
  default     = []
}

variable "path_priority_map" {
  description = "Map of path list and priority for path-based routing"
  type = object({
    app_path_list = list(string)
    priority      = number
  })
  default = {
    app_path_list = ["/"]
    priority      = 1
  }
}
variable "disable_nw_sg" {
  type    = bool
  default = true
}

variable "external_lb_path_based_routing" {
  type    = map(any)
  default = {}
}

variable "redirect_protocol" {
  description = "protocol for redirect action type"
  type        = string
  default     = "HTTPS"
}

variable "redirect_port" {
  description = "port for redirect action type"
  type        = string
  default     = "443"
}

variable "redirect_status_code" {
  description = "status code for redirect action type"
  type        = string
  default     = "HTTP_302"
}

variable "use_redirect_listener" {
  description = "Indicates if it requires for create redirect_listener e.g. g4pwa , g4pwa3"
  type        = bool
  default     = false
}

variable "enable_termination_protection" {
  description = "Set to true to enable termination protection, false to disable."
  type        = bool
  default     = false
}

variable "enable_http2" {
  description = "Enable or disable HTTP/2 for the ALB"
  type        = bool
  default     = true
}
variable "longlived_with_ext_loadbalancer" {
  description = "Is your application long lived with external load balancer? True or False "
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "vpc id passed in deployer (if any)"
  type        = string
  default     = null
}
