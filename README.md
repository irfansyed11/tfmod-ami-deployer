# tfmod-ami-deployer
# ami-deployer

The `ami-deployer` is intended to remove the hands-on pain of deploying AMIs.
The `ami-deployer` handles initially standing up the infrastructure for a
specific AMI with a couple of supported deployment patterns, either with or
without an [Auto Scaling Group](https://docs.aws.amazon.com/autoscaling/ec2/userguide/AutoScalingGroup.html) (ASG).
For those deployments using an ASG the `ami-deployer` can automatically update
the deployment with new versions of the AMI being used.

The full AMI pipeline, both builder and `ami-deployer` is captured in the
architectural diagram `AMI_Creation_Arch.png`. The `ami-deployer`, in that
diagram, is the [Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html) and everything to the right.
The integration point for the builder and deployer is the Parameter Store.

The `ami-deployer` is intended to be used as a child module. The root module
is reponsible for managing any deployment specific resources and can fetch
information required by the `ami-deployer`.

## Supported features

### Deployments

#### **Launch configuration**

Regardless of how the instances are deployed the the configuration options that
supported are outlined below. Deviations should be captured in specific
sections of the documentation. A known deviation is the support for assigning
private IP addresses to instances deployed outside of an ASG.

**WET WARNING**: (by wet we're not DRY) instances deployed in an ASG use a
launch template whereas instances deployed outside of an ASG use the
configuration defined directly on the `aws_instance`. The ability for an
`aws_instance` to use a launch template is relatively new feature added to the
AWS provider and the documented ability to have the `aws_instance` attributes
override the launch template configuration does not seem accurate. Once this
issue is addressed the `ami-deployer` can be updated to use the launch template
for all deployments.

`initial_deployment_ami_id`: specifies the ID of the AMI that will be used
by the instances being deployed. This variable is qualified as "initial"
to make it clear that the AMI specified here is used the when the deployer is
first applied.

`deployment_instance_type`: the type of instance to use. Example: `t3.small`.

`deployment_security_group_ids`: the IDs of the security groups applied to
the instance.

`deployment_key_pair_name`: the name of the key-pair to associcate with the
instance.

`instance_iam_profile`: the instance profile to associate with the instance.

`instance_tags`: tags to assign to the instance.

`bootstrap_script_inline`: a heredoc that contains the instance userdata that
will be executed during instance launch. The userdata can also be provided as
a file using the `bootstrap_script_file`. If both variables are provided this
takes precedence.

`bootstrap_script_file`: the path to a file to use for the instance userdata.
The path provided should be relative to `${path.root}/`. The userdata can also
be defined inline using the `bootstrap_script_inline` variable. If both
variables are provided *the inline value takes precedence*.

#### **With Auto Scaling Group**

Deploying instances in an ASG is the default. The variable that toggles the
use of an ASG is `use_autoscaling_group`. The following are the variables that
are used to configure the ASG.

`target_autoscaling_group_name`: the name of the ASG. This value is used as
a prefix for several other resources managed by the `ami-deployer`. The launch
template used to spinup instances is tagged with this value and most
importantly the Lambda that handles auto-deployments is provided this value
as an environment variable.

`deployment_subnet_ids`: the IDs of the subnets to launch ASG managed
instances.

`service_capacity`: the number of instances the group should contain.

`service_max_size`: the upperbound of instances the group can launch.

`service_min_size`: the lowerbound of instances the group can launch.

`health_check_type`: the type of health check that should be used to
determine the health of the instances. Supported options are `ELB` or `EC2`.
The default is `EC2`.

`service_health_check_wait`: how long to wait in seconds before launched
instances have their health checked.

#### **Using Scaling Policies**

At this time only `simple scaling` is supported and can be configured with the variable below in `variabled.tf`:

`NOTE: if you only set values for asg_policy_out and asg_policy_in then the default alarms configured below will be used. Not setting values for the these policies will result in the policies and alarms being turned off.`

**Example `asg_policy_out` Object**

```terraform
{
  scaling_adjustment  = "1"
  cooldown            = "300"
}
```

**Example `asg_policy_in` Object**

```terraform
{
  scaling_adjustment  = "-1"
  cooldown            = "300"
}
```

**Example `asg_metric_alarm_in` Object**

```terraform
{
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "40"
}
```

**Example `asg_metric_alarm_out` Object**

```terraform
{
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
}
```

#### **Without Auto Scaling Group**

There are certain scenarios where you may need to launch instances not in an Auto Scaling Group (DB2, Domain Controllers) due to them not complying with the immutable update process, having clustering mechanisms that cannot cope with autoscaling, the need for static private ip's, etc. The `ami-deployer` has been engineered to handle this scenario as follows:

- Set the Variable `use_autoscaling_group` to `false`

    ```terraform
    variable "use_autoscaling_group" {
      description = "Indicates if the deployed instances should be launched in an autoscaling group"
      type        = bool
      default     = true
    }
    ```

- If static private ip's are needed, set `instance_ips`

    ```terraform
    variable "instance_ips" {
      description = "An object composed of private ip's and their subnets to allocate to instances not launched in an ASG."
      type        = list(map(string))
      default     = []
    }
    ```

**Example private_ip object**:

```terraform
[
  {
    subnet_id = "subnet-1"
    ip        = "1.1.1.1"
  },
  {
    ...
  }
]
```
**Example instance_extra_disks object**:

```terraform

  {
    disk1 = {
      device_name = "/dev/sdb1"
      volume_size = 100
    }
    disk2 = {
      device_name = "/dev/sdb2"
      volume_size = 500
      volume_type = "gp3"
      iops        = 5000
      throughput  = 250
    }
  }

```

### To balance or not to balance

All deployments can be fronted by a load balancer. Whether or not the
deployment is fronted or not is controlled by the `use_load_balancer` variable.
The default has `use_load_balancer` set to `true`. If a load balancer isn't
desired set `use_load_balancer` to `false`.

You can conditionally use a pre-existing `external` load balancer by passing in the `ARN` of the load balancer as `external_load_balancer` and the `VPC` it resides in to `service_vpc_id`. You must also set `use_load_balancer` to `false`, otherwise an internal ELB will be provisioned and not used.

`NOTE: use of instances not in an ASG is not currently supported with an external ELB. This is not a functionality limitation of AWS, it just requires a rewrite of much of the logic in this template that has not taken place yet`

Two types of load balancers are supported: Layer 7 [Application Load Balancer](https://aws.amazon.com/elasticloadbalancing/application-load-balancer/) (ALB)
and Layer 4 [Network Load Balancer](https://aws.amazon.com/elasticloadbalancing/network-load-balancer/) (NLB). The default load balancer used is
the ALB. To control which type of load balancer to use set the variable
`load_balancer_type` to either `application` or `network`.

#### **Configuration options**

The following are variables that influence the load balancer configuration:

`lb_security_group_ids`: allows assigning specific security groups to the
load balancer.

`disallow_load_balancer_deletion`: when `true` load balancer deletion
protection is enabled. Deletion protection is disabled by default.

`external_load_balancer`: pass the `ARN` of the pre-existing `external` load balancer to attach the `Listener` to.

#### **Listeners**

By default the load balancer will use a single listener composed of the
of the following variables:

`service_vpc_id`: the ID of the VPC that will house the target group that is
associcated with the listener. If using an external load balancer, this must be set to the `VPC` the load balancer already exists in.

`service_protocol`: the protocol the listener will capture and pass to the
target group. Default: HTTP.

`service_port`: the port the listener will capture traffic on and the port it
will send traffic to on the target group. Default: 80.

The `ami-deployer` supports defining multiple listeners for the load balancer.
To define multiple listeners use the `load_balancer_listeners` variable.

**Example of multiple listener**:

```terraform
{
  http = {
    service_vpc_id   = "vpc-1"
    service_protocol = "HTTP"
    service_port     = 80
  },
  https = {
    service_vpc_id   = "vpc-1"
    service_protocol = "HTTPS"
    service_port     = 443
  }
}
```

Depending on the load balancer used the supported protocols will vary.

For SSL offloading provide the following two attributes to the objects in
the example above: `certificate_arn` and `ssl_policy`.

#### **Health checks**

If `health_check_type` is set to `ELB` the load balancer performs health checks
on the instances it's fronting. Currently only a single custom health check
can be defined and it's applied to all target groups.

If a custom health check isn't provided the default health check expects to
receive an `HTTP 200 OK` over port 80 on the root path "`/`". This no doubt is
not going to fit the bill for many, really any, deployments so it's best to
either stick with `EC2` health checks or provide a custom health check for
the `ELB` option.

Providing the following structure as the value for `elb_health_check` will
allow the custom health check to be used with `health_check_type` is `ELB`:

For ALB:

```terraform
{
  "enabled"             = "true"
  "healthy_threshold"   = "3"
  "interval"            = "30"
  "path"                = "/"
  "port"                = "traffic-port"
  "protocol"            = "HTTP"
  "unhealthy_threshold" = "3"
  "matcher"             = "200"
  "timeout"             = "5"
}
```

For NLB:

```terraform
{
  "enabled"             = "true"
  "healthy_threshold"   = "3"
  "interval"            = "30"
  "path"                = "/"
  "port"                = "traffic-port"
  "protocol"            = "HTTP"
  "unhealthy_threshold" = "3"
  "matcher"             = "200-399"
}
```

For more information on the attributes jump over [here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group#health_check).

### Lifecycle events

#### **Launch**

The `ami-deployer` supports performing leader election when instances are being
deployed in an ASG. If the `leader_election_strategy` variable is set a
`EC2_INSTANCE_LAUNCHING` lifecycle hook is created for the ASG. For additional
information head over to the `leader-elector` repository.

**NOTE**: the launch lifecycle hook is configured using a block configuration
on the ASG because if it's not and this is the first time the ASG is being
created instances will be launched and the lifecycle hook won't be honored.
The drawback to this is if leader election is enabled AFTER the ASG has already
been created the launch lifecycle hook will NOT be attached to the
ASG.

#### **Termination**

The `ami-deployer` supports having a terminator run when the
`EC2_INSTANCE_TERMINATING` event occurs by setting the
`instance_termination_handler` variable. For additional information head over
to the `instance-terminator` repository.

**NOTE**: Unlike the launch lifecycle hook the termination hook is created
using a separate resource. This means when the ASG is launching for the first
time if instances are being terminated (failing to launch) the terminator
will not run. It's unlikely this is an issue. If an ASG can not successfully
launch the first time there's larger issues at play that likely involves human
intervention.

## Example Deployer Configurations

### Example: `General`

The following is a general example of how to use the deployer in a standard configuration for most applications.

```terraform
module "deployer" {
  source                        = "../ami-deployer"
  aws_region                    = "us-east-2"
  deployment_name               = "test-deployer"
  deployment_instance_type      = "t3a.small"
  deployment_subnet_ids         = ["subnet-00bbecb7a75f63e25","subnet-00d31b2e560b21f0c","subnet-0f8bf83b36491af0e"]
  deployment_security_group_ids = ["sg-0c8d318bca4944f18"]
  initial_deployment_ami_id     = data.aws_ami.initial_ami.id
  use_autoscaling_group         = true
  use_load_balancer             = false
  image_recipe_name             = "linux-gold-recipe"
  external_load_balancer        = "arn:aws:elasticloadbalancing:us-east-2:879624941994:loadbalancer/app/jbshc1/50c010b1c14ad8a9"
  service_vpc_id                = ""vpc-011fac535724456df""
  service_capacity              = 3
  service_min_size              = 2
  service_max_size              = 5
  target_autoscaling_group_name = "test-deployer"
  lambda_logging_policy_arn     = data.aws_iam_policy.cloudwatch_log_access.arn
  lambda_param_store_policy_arn = data.aws_iam_policy.parameter_store_access.arn
  bootstrap_script_inline       = <<EOF
}
```

### Example: `No ASG without static IP's`

The following example shows how to use the deployer to launch a group of instances NOT in an Autoscaling Group that do not have static ip's.

```terraform
module "deployer" {
  source                        = "git::ssh://git@git.allegiantair.com:7999/aw/ami-deployer.git?ref=v1.0.14"

  aws_region                       = var.aws_region
  deployment_name                  = var.deployment_name
  deployment_instance_type         = "t3a.medium"
  service_capacity                 = 1
  service_max_size                 = 1
  service_min_size                 = 1
  use_autoscaling_group            = false
  use_load_balancer                = false
  deployment_subnet_ids            = data.aws_subnet_ids.private.ids
  deployment_security_group_ids    = [aws_security_group.stack-sg.id]
  initial_deployment_ami_id        = data.aws_ami.initial_ami.id
  instance_tags                    = local.instance_tags
  instance_iam_profile             = aws_iam_instance_profile.ec2_iam_profile.name
  tags                             = local.deployer_tags
  instance_ips                  = [
                                    {
                                      subnet_id = "subnet-00bbecb7a75f63e25" #dr-aws_app-private-us-east-2b
                                    }
                                  ]
  # The next four args shouldn't be required
  image_recipe_name                = "spring-boot-recipe"
  lambda_logging_policy_arn        = data.aws_iam_policy.cloudwatch_log_access.arn
  lambda_param_store_policy_arn    = data.aws_iam_policy.parameter_store_access.arn
  target_autoscaling_group_name    = "${var.deployment_name}-asg"

  # Cloud-init
  bootstrap_script_inline          = <<EOF
#cloud-config
hostname: "${var.deployment_name}"
fqdn: "$zipws01.prd02.aws.allegiantair.com"

runcmd:
  - cd /root/sdlc_deploy; git pull; ansible-playbook zipws.yml
EOF
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.41.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.2 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.11.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws_tagger"></a> [aws\_tagger](#module\_aws\_tagger) | git::git@github.com:AllegiantTravelCo/tfmod-aws-tagger.git | experimental |

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_attachment.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment) | resource |
| [aws_autoscaling_attachment.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment) | resource |
| [aws_autoscaling_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_lifecycle_hook.termination](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_autoscaling_policy.in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_autoscaling_policy.out](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_cloudwatch_log_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.out](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_elasticache_cluster.elasticache_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_cluster) | resource |
| [aws_elasticache_subnet_group.elasticache-memcached-subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_iam_instance_profile.ec2_iam_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ec2_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ec2_iam_role_ssm_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ec2_iam_role_ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.default_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.listener_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.listener_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_certificate.extra_certificate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_listener_certificate.extra_certificate_path_based](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_listener_rule.host_based_routing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.path_based_routing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.path_based_routing_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.path_based_routing_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.ext_listener_tg_path_based](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.external_listener_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.path_based_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_msk_cluster.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_cluster) | resource |
| [aws_security_group.stack-sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [null_resource.sns_publisher](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_integer.path_based_priority](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) | resource |
| [random_integer.priority](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) | resource |
| [random_integer.priority1](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) | resource |
| [time_static.main](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy.core_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.read_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_lb.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_lb.path_based_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.region](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.account_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.ami_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aws_acm_certificate_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aws_acm_certificate_arn_allegiantair](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.control_tower_environment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.dns_domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.environment_type](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.network_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.ou_logical_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.route53_zone_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.sub_env](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.vpc_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnet.vpc_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnet.vpc_subnet_az_info](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.vpc_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_subnets.vpc_subnets_targeted](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_lb_certificate"></a> [additional\_lb\_certificate](#input\_additional\_lb\_certificate) | n/a | `bool` | `false` | no |
| <a name="input_allow_stickiness"></a> [allow\_stickiness](#input\_allow\_stickiness) | allow stickiness for NLB | `bool` | `false` | no |
| <a name="input_ansible_group"></a> [ansible\_group](#input\_ansible\_group) | Automation Tags, used in Ansible playbook - Ex Val(s): aisap | `string` | `null` | no |
| <a name="input_ansible_groups"></a> [ansible\_groups](#input\_ansible\_groups) | Automation Tags, used in Ansible playbook - Ex Val(s): [g4www,combo,cmbap] | `string` | `null` | no |
| <a name="input_app_in_ports"></a> [app\_in\_ports](#input\_app\_in\_ports) | Ingress Ports/CIDRS for Security Group | `map(any)` | `null` | no |
| <a name="input_app_out_ports"></a> [app\_out\_ports](#input\_app\_out\_ports) | Egresss Ports/CIDRS for Security Group | `map(any)` | <pre>{<br>  "default_out": {<br>    "cidrs": [<br>      "0.0.0.0/0"<br>    ],<br>    "desc": "All ports/ips outbound",<br>    "from": 0,<br>    "protocol": "-1",<br>    "to": 0<br>  }<br>}</pre> | no |
| <a name="input_apps"></a> [apps](#input\_apps) | List of applications that make up the application group or application bundle. | `list(any)` | `[]` | no |
| <a name="input_asg_metric_alarm_in"></a> [asg\_metric\_alarm\_in](#input\_asg\_metric\_alarm\_in) | The Simple Scaling Metric Alarm to be used when the ASG scales in | `map(string)` | `{}` | no |
| <a name="input_asg_metric_alarm_out"></a> [asg\_metric\_alarm\_out](#input\_asg\_metric\_alarm\_out) | The Simple Scaling Metric Alarm to be used when the ASG scales out | `map(string)` | `{}` | no |
| <a name="input_asg_policy_in"></a> [asg\_policy\_in](#input\_asg\_policy\_in) | The Simple Scaling Policy to be used when the ASG scales in | `map(string)` | `null` | no |
| <a name="input_asg_policy_out"></a> [asg\_policy\_out](#input\_asg\_policy\_out) | The Simple Scaling Policy to be used when the ASG scales out | `map(string)` | `null` | no |
| <a name="input_backend_service_port"></a> [backend\_service\_port](#input\_backend\_service\_port) | The port the load balancer will send traffic | `string` | `null` | no |
| <a name="input_backend_service_protocol"></a> [backend\_service\_protocol](#input\_backend\_service\_protocol) | The protocol the load balancer will use when sending traffic | `string` | `null` | no |
| <a name="input_backup_schedule"></a> [backup\_schedule](#input\_backup\_schedule) | Automation Tags, identifies backups/snapshots schedule - Ex Val(s): 6h\|daily\|weekly\|monthly | `string` | `null` | no |
| <a name="input_bootstrap_script_file"></a> [bootstrap\_script\_file](#input\_bootstrap\_script\_file) | Path to a bootstrap script that will base64 encoded and provided as userdata to the EC2 instance. path.root/ is prepended. | `string` | `null` | no |
| <a name="input_bootstrap_script_inline"></a> [bootstrap\_script\_inline](#input\_bootstrap\_script\_inline) | The value provided here will be base64 encoded and provided as userdata to the EC2 instance | `string` | `null` | no |
| <a name="input_build_info"></a> [build\_info](#input\_build\_info) | Build Information Tag, We will start with Terraform repo but idea is to later replace it with Build info of the package used for the stack - Ex Val(s): Terraform Repo | `string` | `null` | no |
| <a name="input_business_unit"></a> [business\_unit](#input\_business\_unit) | Business Unit Tag, Ex Val(s): Marketing/Stations/Teesnap | `string` | n/a | yes |
| <a name="input_change_ticket"></a> [change\_ticket](#input\_change\_ticket) | CM Ticket/Release Key Tag, Ex Val(s): CM123455 | `string` | `null` | no |
| <a name="input_compliance_status"></a> [compliance\_status](#input\_compliance\_status) | Compliance Tag, dynamic tag applied by Security Automation - Ex Val(s): compliant/non-compliant | `string` | n/a | yes |
| <a name="input_cost_center"></a> [cost\_center](#input\_cost\_center) | Cost Center Tag, Ex Val(s): 459/460/461 | `string` | n/a | yes |
| <a name="input_create_msk_cluster"></a> [create\_msk\_cluster](#input\_create\_msk\_cluster) | Create a MSK Cluser | `bool` | `false` | no |
| <a name="input_days_to_retain_logs"></a> [days\_to\_retain\_logs](#input\_days\_to\_retain\_logs) | The number of days to retain cloudwatch logs. Values: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653 | `number` | `0` | no |
| <a name="input_default_vpc"></a> [default\_vpc](#input\_default\_vpc) | Name of the default VPC | `string` | `"default-vpc"` | no |
| <a name="input_deployment_instance_type"></a> [deployment\_instance\_type](#input\_deployment\_instance\_type) | The instance type to use for the AMI being deployed | `string` | `null` | no |
| <a name="input_deployment_key_pair_name"></a> [deployment\_key\_pair\_name](#input\_deployment\_key\_pair\_name) | The EC2 instance key-pair name to use | `string` | `null` | no |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment artifact. Used as a resource prefix. | `string` | n/a | yes |
| <a name="input_deployment_security_group_ids"></a> [deployment\_security\_group\_ids](#input\_deployment\_security\_group\_ids) | A list of security groups to associate with the deployed EC2 instances | `list(string)` | `null` | no |
| <a name="input_deployment_subnet_ids"></a> [deployment\_subnet\_ids](#input\_deployment\_subnet\_ids) | A list of security groups to associate with the deployed EC2 instances | `list(string)` | `[]` | no |
| <a name="input_disable_nw_sg"></a> [disable\_nw\_sg](#input\_disable\_nw\_sg) | n/a | `bool` | `true` | no |
| <a name="input_dns_check"></a> [dns\_check](#input\_dns\_check) | dns check either allegiant.com or allegiantair.com | `string` | `"allegiant.com"` | no |
| <a name="input_dns_cnames"></a> [dns\_cnames](#input\_dns\_cnames) | List of fqhn for dns cname creation for alb (Optional). | `list(any)` | `[]` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain Information Tag, Ex Val: Digital Customer System/Flight Operations System | `string` | n/a | yes |
| <a name="input_drop_invalid_header"></a> [drop\_invalid\_header](#input\_drop\_invalid\_header) | Drop isnvalid header - True/False | `bool` | `false` | no |
| <a name="input_ec2_image_builder"></a> [ec2\_image\_builder](#input\_ec2\_image\_builder) | True, if the AMIs are built using EC2 Image Builder | `bool` | `true` | no |
| <a name="input_ec2_schedule"></a> [ec2\_schedule](#input\_ec2\_schedule) | Automation Tags, used with auto on/off lambdas for cost management - Ex Val(s): las\_vegas\_office\_hours | `string` | `"always-on"` | no |
| <a name="input_ec_dns_name"></a> [ec\_dns\_name](#input\_ec\_dns\_name) | DNS record name for the elastic memcached cluster | `string` | `"test-ec"` | no |
| <a name="input_ec_engine"></a> [ec\_engine](#input\_ec\_engine) | engine | `string` | `"memcached"` | no |
| <a name="input_ec_node_type"></a> [ec\_node\_type](#input\_ec\_node\_type) | node type | `string` | `"cache.m4.large"` | no |
| <a name="input_ec_port"></a> [ec\_port](#input\_ec\_port) | Port number for the elastic memcached cluster | `number` | `"11211"` | no |
| <a name="input_elb_health_check"></a> [elb\_health\_check](#input\_elb\_health\_check) | The ELB health check used if health\_check\_type is set to ELB. If a health check is not provided the default ELB health check is used. | `map(string)` | `{}` | no |
| <a name="input_elb_listener_ssl_policy"></a> [elb\_listener\_ssl\_policy](#input\_elb\_listener\_ssl\_policy) | The AWS ssl policy for cert/key combo used by elb listener(s) | `string` | `"ELBSecurityPolicy-FS-1-2-Res-2019-08"` | no |
| <a name="input_elb_subnet_ids"></a> [elb\_subnet\_ids](#input\_elb\_subnet\_ids) | A list of security groups to associate with the elb | `list(string)` | `[]` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Force deletion of load balancer using management console | `bool` | `false` | no |
| <a name="input_enable_route53_record"></a> [enable\_route53\_record](#input\_enable\_route53\_record) | Whether to create DNS records | `bool` | `true` | no |
| <a name="input_enable_termination_protection"></a> [enable\_termination\_protection](#input\_enable\_termination\_protection) | Set to true to enable termination protection, false to disable. | `bool` | `false` | no |
| <a name="input_ext_listener_arn_path_based"></a> [ext\_listener\_arn\_path\_based](#input\_ext\_listener\_arn\_path\_based) | external load balancer listner for path based routing | `list(any)` | `[]` | no |
| <a name="input_ext_tg"></a> [ext\_tg](#input\_ext\_tg) | External/Existing Target Group for LoadBalancer | `string` | `null` | no |
| <a name="input_external_lb_path_based_routing"></a> [external\_lb\_path\_based\_routing](#input\_external\_lb\_path\_based\_routing) | n/a | `map(any)` | `{}` | no |
| <a name="input_external_listener_arn"></a> [external\_listener\_arn](#input\_external\_listener\_arn) | external\_listener\_arn | `string` | `null` | no |
| <a name="input_external_listener_host"></a> [external\_listener\_host](#input\_external\_listener\_host) | external\_listener\_host | `string` | `null` | no |
| <a name="input_external_load_balancer"></a> [external\_load\_balancer](#input\_external\_load\_balancer) | Indicates that the template should attach to an external (pre-existing) load balancer instead of creating one. The only accepted value is the full ARN of the load balancer to attach to, otherwise leave value as null. | `string` | `null` | no |
| <a name="input_feature_version"></a> [feature\_version](#input\_feature\_version) | Feature Version Tag, Version of a specific Feature - Ex Val(s}: v1.5.10 | `string` | `null` | no |
| <a name="input_fqdn"></a> [fqdn](#input\_fqdn) | FQDN/ALB Name Tag, to identify the FQDN - Ex Val(s): fqdn for the application | `string` | `null` | no |
| <a name="input_health_check_down_thresh"></a> [health\_check\_down\_thresh](#input\_health\_check\_down\_thresh) | On the ELB, number of consecutive health check fails before marking target unhealthy | `number` | `5` | no |
| <a name="input_health_check_enabled"></a> [health\_check\_enabled](#input\_health\_check\_enabled) | Flag to enable ELB health check on target hosts | `bool` | `true` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | ELB health check interval in seconds | `number` | `50` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | ELB health check path | `string` | `"/"` | no |
| <a name="input_health_check_ret_vals"></a> [health\_check\_ret\_vals](#input\_health\_check\_ret\_vals) | ELB health check HTTP return value range from target | `string` | `"200-299"` | no |
| <a name="input_health_check_timeout"></a> [health\_check\_timeout](#input\_health\_check\_timeout) | ELB health check timeout in seconds | `number` | `30` | no |
| <a name="input_health_check_type"></a> [health\_check\_type](#input\_health\_check\_type) | The type of health check the autoscaling group will use on the instances | `string` | `"ELB"` | no |
| <a name="input_health_check_up_tresh"></a> [health\_check\_up\_tresh](#input\_health\_check\_up\_tresh) | On the ELB, number of consecutive health check successes before marking target healthy | `number` | `2` | no |
| <a name="input_http_service_port"></a> [http\_service\_port](#input\_http\_service\_port) | The (optional) HTTP service port used by the elb listener | `string` | `null` | no |
| <a name="input_idle_timeout"></a> [idle\_timeout](#input\_idle\_timeout) | The time in seconds that the connection is allowed to be idle. | `string` | `60` | no |
| <a name="input_in_transit_encryption"></a> [in\_transit\_encryption](#input\_in\_transit\_encryption) | Encryption setting for data in transit | `string` | `null` | no |
| <a name="input_initial_deployment_ami_id"></a> [initial\_deployment\_ami\_id](#input\_initial\_deployment\_ami\_id) | The initial AMI to use when deploying. Post initial deployment the AMI is managed. | `string` | `null` | no |
| <a name="input_initiative_id"></a> [initiative\_id](#input\_initiative\_id) | Jira Initiative ID Tag, Ex Val(s): san\_123435 | `string` | n/a | yes |
| <a name="input_inline_policy"></a> [inline\_policy](#input\_inline\_policy) | IAM Inline Policy (String) | `string` | `""` | no |
| <a name="input_instance_extra_disks"></a> [instance\_extra\_disks](#input\_instance\_extra\_disks) | An object composed of maps that describe extra ebs disks | `map(any)` | `{}` | no |
| <a name="input_instance_iam_profile"></a> [instance\_iam\_profile](#input\_instance\_iam\_profile) | Input iam instance profile name when create outside module. | `string` | `null` | no |
| <a name="input_instance_ips"></a> [instance\_ips](#input\_instance\_ips) | An object composed of private ip's and their subnets to allocate to instances not launched in an ASG. | `list(map(string))` | `[]` | no |
| <a name="input_instance_tags"></a> [instance\_tags](#input\_instance\_tags) | Optional tags to apply to the deployment EC2 instances. Instance tag template overrides can be provided here. | `map(string)` | `{}` | no |
| <a name="input_instance_tags_template"></a> [instance\_tags\_template](#input\_instance\_tags\_template) | Expected tags for the deployment EC2 instances. Merged with tags\_template so tag template overrides can be provided here. | `map(string)` | `{}` | no |
| <a name="input_instance_termination_handler"></a> [instance\_termination\_handler](#input\_instance\_termination\_handler) | "The termination handler to use on the autoscaling group instances.<br>Allowed value: 'mongo'. The default is 'null' which means no termination handling performed." | `string` | `null` | no |
| <a name="input_internal_alb"></a> [internal\_alb](#input\_internal\_alb) | Internal ALB True/False | `bool` | `true` | no |
| <a name="input_is_live"></a> [is\_live](#input\_is\_live) | Live/Non Live Flag Tag, Ex Val(s): true/false | `string` | `"true"` | no |
| <a name="input_is_node_communication_encrypted"></a> [is\_node\_communication\_encrypted](#input\_is\_node\_communication\_encrypted) | Indicates whether data communication between broker nodes is encrypted | `bool` | `true` | no |
| <a name="input_kafka_version"></a> [kafka\_version](#input\_kafka\_version) | The version of kafka to run | `string` | `"2.2.1"` | no |
| <a name="input_lb_stickiness_type"></a> [lb\_stickiness\_type](#input\_lb\_stickiness\_type) | Type of lb stickiness e.g NLB -> source\_ip , ALB -> lb\_cookie or app\_cookie | `string` | `null` | no |
| <a name="input_leader_election_strategy"></a> [leader\_election\_strategy](#input\_leader\_election\_strategy) | "Indicates the type of leader election strategy employed on the autoscaling group instances.<br>Allowed value: 'simple'. The default is 'null' which means no leader election." | `string` | `null` | no |
| <a name="input_load_balancer_listeners"></a> [load\_balancer\_listeners](#input\_load\_balancer\_listeners) | Each element in the list defines a listener that will be associated with the load balancer. Note a target group for each listener will be created. | `map(any)` | <pre>{<br>  "http-tcp": {},<br>  "https-tcp": {}<br>}</pre> | no |
| <a name="input_load_balancer_redirect_listener"></a> [load\_balancer\_redirect\_listener](#input\_load\_balancer\_redirect\_listener) | Each element in the list defines a listener that will be associated with the load balancer. Note a target group for each listener will be created. | `map(any)` | `{}` | no |
| <a name="input_load_balancer_security_group_ids"></a> [load\_balancer\_security\_group\_ids](#input\_load\_balancer\_security\_group\_ids) | A list of security groups to associate with the load balancer. The default is no security groups. | `list(string)` | `null` | no |
| <a name="input_load_balancer_type"></a> [load\_balancer\_type](#input\_load\_balancer\_type) | Selects whether to use a network or application load balancer. Valid values: network, application. | `string` | `null` | no |
| <a name="input_managed_policies"></a> [managed\_policies](#input\_managed\_policies) | List of ARNs of IAM policies to attach to main IAM role | `list(string)` | `[]` | no |
| <a name="input_mongo_secret_key"></a> [mongo\_secret\_key](#input\_mongo\_secret\_key) | The key to use to extract connection uri from the mongo secret with the name specified by mongo\_secret\_name | `string` | `""` | no |
| <a name="input_mongo_secret_name"></a> [mongo\_secret\_name](#input\_mongo\_secret\_name) | The name of the secret in secrets manager that contains the connection uri information | `string` | `""` | no |
| <a name="input_monitoring_level"></a> [monitoring\_level](#input\_monitoring\_level) | Enhanced CloudWatch monitoring level. Valid values: DEFAULT, PER\_BROKER, PER\_TOPIC\_PER\_BROKER, PER\_TOPIC\_PER\_PARTITION. | `string` | `"PER_TOPIC_PER_BROKER"` | no |
| <a name="input_need_ec2_tags"></a> [need\_ec2\_tags](#input\_need\_ec2\_tags) | Do you need EC2 tags? True or False | `bool` | `true` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Number of broker nodes. Must be a multiple of the number of node subnets. | `number` | `3` | no |
| <a name="input_node_instance_type"></a> [node\_instance\_type](#input\_node\_instance\_type) | The compute to use for each broker node | `string` | `"kafka.m5.large"` | no |
| <a name="input_node_storage_size"></a> [node\_storage\_size](#input\_node\_storage\_size) | The size (GiB) of the EBS volume for each broker node | `number` | `1000` | no |
| <a name="input_os"></a> [os](#input\_os) | Operating System Tag, Ex Val(s): linux\|windows | `string` | `"linux"` | no |
| <a name="input_parameter_group_name"></a> [parameter\_group\_name](#input\_parameter\_group\_name) | Parameter group name | `string` | `"default.memcached1.6"` | no |
| <a name="input_patch_group"></a> [patch\_group](#input\_patch\_group) | Automation Tags, identifiies patch group - Ex Val(s): awstbedpstest\_test\_dps\_tbe\_hours | `string` | `null` | no |
| <a name="input_path_priority_map"></a> [path\_priority\_map](#input\_path\_priority\_map) | Map of path list and priority for path-based routing | <pre>object({<br>    app_path_list = list(string)<br>    priority      = number<br>  })</pre> | <pre>{<br>  "app_path_list": [<br>    "/"<br>  ],<br>  "priority": 1<br>}</pre> | no |
| <a name="input_persistent_team_name"></a> [persistent\_team\_name](#input\_persistent\_team\_name) | Persistent Team Tag, Ex Val(s): partywolves/clouddoctors | `string` | n/a | yes |
| <a name="input_preserve_client_ip"></a> [preserve\_client\_ip](#input\_preserve\_client\_ip) | Flag to enable/disable preserve client IP | `bool` | `true` | no |
| <a name="input_product_name"></a> [product\_name](#input\_product\_name) | Product Information Tag | `string` | n/a | yes |
| <a name="input_redirect_port"></a> [redirect\_port](#input\_redirect\_port) | port for redirect action type | `string` | `"443"` | no |
| <a name="input_redirect_protocol"></a> [redirect\_protocol](#input\_redirect\_protocol) | protocol for redirect action type | `string` | `"HTTPS"` | no |
| <a name="input_redirect_status_code"></a> [redirect\_status\_code](#input\_redirect\_status\_code) | status code for redirect action type | `string` | `"HTTP_302"` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Blue/Green Information Tag to support Blue and Green Stack, Ex Val(s): blue/green | `string` | `"Blue"` | no |
| <a name="input_service_capacity"></a> [service\_capacity](#input\_service\_capacity) | The desired capacity of the autoscaling group managing the deployment instances | `number` | `1` | no |
| <a name="input_service_health_check_wait"></a> [service\_health\_check\_wait](#input\_service\_health\_check\_wait) | Seconds to wait before health checks are applied to a new instance | `number` | `180` | no |
| <a name="input_service_host_name"></a> [service\_host\_name](#input\_service\_host\_name) | (Deprecated, use dns\_cnames instead).  The traffic hostname that the load balancer will forward | `string` | `"some.host.info"` | no |
| <a name="input_service_max_size"></a> [service\_max\_size](#input\_service\_max\_size) | The max size of the autoscaling group managing the deployment instances | `number` | `2` | no |
| <a name="input_service_min_size"></a> [service\_min\_size](#input\_service\_min\_size) | The min size of the autoscaling group managing the deployment instances | `number` | `1` | no |
| <a name="input_service_port"></a> [service\_port](#input\_service\_port) | The port the load balancer will send traffic | `number` | `80` | no |
| <a name="input_service_protocol"></a> [service\_protocol](#input\_service\_protocol) | The protocol the load balancer will use when sending traffic | `string` | `"HTTP"` | no |
| <a name="input_service_redirect_host"></a> [service\_redirect\_host](#input\_service\_redirect\_host) | If the load balancer listener rules do not trigger an action the listener redirects to this host | `string` | `null` | no |
| <a name="input_service_redirect_path"></a> [service\_redirect\_path](#input\_service\_redirect\_path) | If the load balancer listener rules do not trigger an action the listener redirects to 'service\_redirect\_host + service\_redirect\_path' | `string` | `null` | no |
| <a name="input_ssl_service_port"></a> [ssl\_service\_port](#input\_ssl\_service\_port) | SSL service port | `string` | `null` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | Stack Name Tag | `string` | n/a | yes |
| <a name="input_stack_role"></a> [stack\_role](#input\_stack\_role) | Feature Role Tag, Ex Val(s): web, middleware, db | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to add to created AWS resources | `map(string)` | `{}` | no |
| <a name="input_tags_template"></a> [tags\_template](#input\_tags\_template) | Expected tags for resources | `map(string)` | `{}` | no |
| <a name="input_target_type"></a> [target\_type](#input\_target\_type) | target\_type for Target Group | `string` | `"instance"` | no |
| <a name="input_use_autoscaling_group"></a> [use\_autoscaling\_group](#input\_use\_autoscaling\_group) | Indicates if the deployed instances should be launched in an autoscaling group | `bool` | `true` | no |
| <a name="input_use_ec2_instaces"></a> [use\_ec2\_instaces](#input\_use\_ec2\_instaces) | Indicates if the deployed instances should be launched in an autoscaling group | `bool` | `false` | no |
| <a name="input_use_elasticcache_cluster"></a> [use\_elasticcache\_cluster](#input\_use\_elasticcache\_cluster) | Indicates if the elasticcache\_cluster should be created. | `bool` | `false` | no |
| <a name="input_use_external_load_balancer_listner"></a> [use\_external\_load\_balancer\_listner](#input\_use\_external\_load\_balancer\_listner) | Indicates if the deployment should be fronted by a load balancer | `bool` | `false` | no |
| <a name="input_use_load_balancer"></a> [use\_load\_balancer](#input\_use\_load\_balancer) | Indicates if the deployment should be fronted by a load balancer | `bool` | `true` | no |
| <a name="input_use_path_based_listener"></a> [use\_path\_based\_listener](#input\_use\_path\_based\_listener) | Indicates if it requires path based routing or not e.g g4pwa , g4pwa3 | `bool` | `false` | no |
| <a name="input_use_redirect_listener"></a> [use\_redirect\_listener](#input\_use\_redirect\_listener) | Indicates if it requires for create redirect\_listener e.g. g4pwa , g4pwa3 | `bool` | `false` | no |
| <a name="input_vertical_name"></a> [vertical\_name](#input\_vertical\_name) | Vertical Information Tag, Ex Val: Commercial/Airline Ops/Corporate | `string` | n/a | yes |
| <a name="input_vpc_subnets_targeted"></a> [vpc\_subnets\_targeted](#input\_vpc\_subnets\_targeted) | Targeted subnets of VPC | `list(string)` | <pre>[<br>  "main-1",<br>  "main-2",<br>  "main-3"<br>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asg"></a> [asg](#output\_asg) | n/a |
| <a name="output_aws_lb_arn"></a> [aws\_lb\_arn](#output\_aws\_lb\_arn) | The ARN of the load balancer. |
| <a name="output_aws_lb_dns_name"></a> [aws\_lb\_dns\_name](#output\_aws\_lb\_dns\_name) | The DNS name of the load balancer. |
| <a name="output_bootstrap_brokers"></a> [bootstrap\_brokers](#output\_bootstrap\_brokers) | n/a |
| <a name="output_ec2_iam_role_name"></a> [ec2\_iam\_role\_name](#output\_ec2\_iam\_role\_name) | n/a |
| <a name="output_elastic_cache_cluster_addr"></a> [elastic\_cache\_cluster\_addr](#output\_elastic\_cache\_cluster\_addr) | n/a |
| <a name="output_ext_lb_target_group_arn"></a> [ext\_lb\_target\_group\_arn](#output\_ext\_lb\_target\_group\_arn) | n/a |
| <a name="output_ext_lb_tg_path_based_arn"></a> [ext\_lb\_tg\_path\_based\_arn](#output\_ext\_lb\_tg\_path\_based\_arn) | n/a |
| <a name="output_lb_listener_arn"></a> [lb\_listener\_arn](#output\_lb\_listener\_arn) | n/a |
| <a name="output_lb_redirect_listener_arn"></a> [lb\_redirect\_listener\_arn](#output\_lb\_redirect\_listener\_arn) | n/a |
| <a name="output_lb_target_group_arn"></a> [lb\_target\_group\_arn](#output\_lb\_target\_group\_arn) | n/a |
| <a name="output_msk_cluster_arn"></a> [msk\_cluster\_arn](#output\_msk\_cluster\_arn) | n/a |
| <a name="output_path_based_tg_arns"></a> [path\_based\_tg\_arns](#output\_path\_based\_tg\_arns) | n/a |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | n/a |
| <a name="output_tg_attachment_to_asg"></a> [tg\_attachment\_to\_asg](#output\_tg\_attachment\_to\_asg) | n/a |
| <a name="output_zookeeper_connect_string"></a> [zookeeper\_connect\_string](#output\_zookeeper\_connect\_string) | n/a |
<!-- END_TF_DOCS -->
