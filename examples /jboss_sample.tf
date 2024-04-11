terraform {
  backend "s3" {
    encrypt        = "true"
    bucket         = "878031627345-tf-remote-state"
    dynamodb_table = "tf-state-lock"
    key            = "tf/ami-deployers/jboss-sample"
    region         = "us-west-2"
  }
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

variable "health_check_type" {
  description = "The type of health check the autoscaling group will use on the instance: EC2 or ELB"
  type        = string
  default     = "ELB"
}

variable "health_check_up_tresh" {
  description = "On the ELB, number of consecutive health check successes before marking target healthy"
  type        = number
  default     = 2
}
locals {
  elb_health_check = {
    enabled             = var.health_check_enabled
    healthy_threshold   = var.health_check_up_tresh
    interval            = var.health_check_interval
    path                = var.health_check_path
    port                = "12680"
    protocol            = "HTTP"
    unhealthy_threshold = var.health_check_down_thresh
    matcher             = var.health_check_ret_vals
    timeout             = var.health_check_timeout
  }  
}

module "deploey_alb" {
 source            = "git::git@github.com:AllegiantTravelCo/tfmod-ami-deployer.git?ref=feature/sk-code-refactor"
 deployment_name    = "jboss-standalone-a2go-notifications"
 app_in_ports      = {
    http_tcp = {
      desc     = "server springboot tcp"
      from     = "80"
      to       = "80"
      protocol = "tcp"
      cidrs    = ["10.0.0.0/8"]
    },
    https_tcp = {
      desc     = "server springboot tcp"
      from     = "443"
      to       = "443"
      protocol = "tcp"
      cidrs    = ["10.0.0.0/8"]
    }
 }
 use_load_balancer             = false                      # SHOULD BE FALSE
 domain_name = "test"
 business_unit            = "TODO: Find business_unit for fmm-flight-translator"
 compliance_status        = "compliant"
 cost_center              = "TODO: Find cost_center for fmm-flight-translator"
 feature_version          = "TODO: Find feature_version for fmm-flight-translator"
 initiative_id            = "TODO: Find initiative_id for fmm-flight-translator"
 persistent_team_name     = "TODO: Find persistent_team_name for fmm-flight-translator"
 product_name             = "fmm-flight-translator"
 stack_name               = "TODO: Find stack_name for fmm-flight-translator"
 stack_role               = "TODO: Find stack_role for fmm-flight-translator"
 vertical_name            = "TODO: Find vertical_name for fmm-flight-translator"
 need_ec2_tags            = false
 external_load_balancer    = "arn:aws:elasticloadbalancing:us-west-2:878031627345:loadbalancer/app/jboss-standalone-jbsch1-lb/6e36a5438180e1b4"
 service_port             = "12680"
 service_protocol         = "HTTP"
 ssl_service_port         = "13043"
 health_check_type        = "ELB"
 http_service_port        = "12680"
 health_check_path        = "/a2go-mobile-notifications/v1/info.json"
 ansible_group  = "jbs046_a2go_notifications"
 ansible_groups = "['jboss','jboss_standalone']"
 bootstrap_script_inline  = <<EOF
#!/bin/bash
echo "fs-b8cd02c3 /opt/jboss_nfs efs _netdev,noresvport,tls,accesspoint=fsap-0c45498df56beab04 0 0" >>/etc/fstab
echo "fs-b8cd02c3 /mnt/filestore efs _netdev,noresvport,tls,accesspoint=fsap-09e1f65ec3ad6064d 0 0" >> /etc/fstab
echo "fs-b8cd02c3 /opt/g4-operations/cassPhotos efs _netdev,noresvport,tls,accesspoint=fsap-0cd87a9e032880837 0 0" >> /etc/fstab
echo "fs-b8cd02c3 /data/content/publication-manager efs _netdev,noresvport,tls,accesspoint=fsap-046825fe85ce07322 0 0" >> /etc/fstab
mount -a
cd /root/repo/sdlc_deploy
git checkout feature/awsprd02_tailored
git pull
/usr/local/aws-cli/v2/2.2.20/bin/aws ssm get-parameter --name vault_lowers --with-decryption --region us-east-2 --output text --query Parameter.Value > vaultpass
/usr/bin/ansible-playbook eap6sa_a2go_notifications.yml --skip-tags consul,filebeat --extra-vars 'jboss_start=False g4_allow_nexus=False' --vault-password-file vaultpass --tags configuration
rm -f vaultpass
hostname $(ifconfig |grep "inet " |grep broadcast|awk '{print $2}' |awk -F '.' '{print "a2go-notifications"$3$4".prd02.aws.allegiantair.com"}')
ifconfig |grep "inet " |grep broadcast|awk '{print $2"  "}' |tr -d '\n' >> /etc/hosts
echo "$(hostname) $(hostname -s)" >> /etc/hosts
systemctl enable collector
systemctl start collector
sleep 30
rm -rf /etc/sumo.conf
/opt/CrowdStrike/falconctl -s --cid=`/usr/local/aws-cli/v2/2.2.20/bin/aws ssm get-parameter --name crowdstrikeCID --with-decryption --region us-east-2 --output text --query Parameter.Value`
systemctl start falcon-sensor
/etc/init.d/jboss-a2go-notifications start
EOF 
} 

provider "aws" {
  region     = "us-west-2"
}
