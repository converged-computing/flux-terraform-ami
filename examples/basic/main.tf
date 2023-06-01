provider "aws" {
  region = var.region
}

# https://github.com/cloudposse/terraform-aws-vpc/blob/master/variables.tf
module "vpc" {
  source     = "cloudposse/vpc/aws"
  version    = "0.18.1"
  cidr_block = "172.16.0.0/16"
  context    = module.this.context
}


module "vpc_endpoints" {
  source                  = "cloudposse/vpc/aws//modules/vpc-endpoints"
  vpc_id                  = module.vpc.vpc_id
  interface_vpc_endpoints = local.interface_vpc_endpoints

  context = module.this.context
}

module "security_group" {
  source     = "cloudposse/security-group/aws"
  version    = "0.3.3"
  rules      = var.security_group_rules
  vpc_id     = module.vpc.vpc_id
  attributes = ["ec2"]
  context    = module.this.context
}


module "subnets" {
  source               = "cloudposse/dynamic-subnets/aws"
  version              = "0.38.0"
  availability_zones   = var.availability_zones
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = false
  nat_instance_enabled = false
  context              = module.this.context
}

module "autoscale_group" {
  source = "cloudposse/ec2-autoscale-group/aws"

  image_id                      = var.image_id
  key_name                      = var.key_name
  instance_type                 = var.instance_type
  instance_market_options       = var.instance_market_options
  mixed_instances_policy        = var.mixed_instances_policy
  subnet_ids                    = module.subnets.public_subnet_ids
  health_check_type             = var.health_check_type
  min_size                      = var.min_size
  max_size                      = var.max_size
  wait_for_capacity_timeout     = var.wait_for_capacity_timeout
  associate_public_ip_address   = true
  user_data_base64              = base64encode(local.userdata)
  metadata_http_tokens_required = var.tokens_required
  security_group_ids            = [module.security_group.id]

  tags = {
    Tier = "1"
  }

  # Auto-scaling policies and CloudWatch metric alarms
  autoscaling_policies_enabled           = false
  cpu_utilization_high_threshold_percent = var.cpu_utilization_high_threshold_percent
  cpu_utilization_low_threshold_percent  = var.cpu_utilization_low_threshold_percent

  block_device_mappings = [
    {
      device_name  = "/dev/sdb"
      no_device    = null
      virtual_name = null
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 8
        volume_type           = "gp2"
        iops                  = null
        kms_key_id            = null
        snapshot_id           = null
      }
    }
  ]
  context = module.this.context
}

# https://www.terraform.io/docs/configuration/expressions.html#string-literals
# TODO we need to understand how the instances are networked, the namespace
# and how we can change the names to be predictible
# https://www.terraform.io/docs/configuration/expressions.html#string-literals
locals {
  zone_id  = "Z0134952203D4J2XTRCUD"
  userdata = <<-USERDATA
    #!/bin/bash
    # TODO mount nfs?
    # sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-******.efs.us-east-1.amazonaws.com:/ /sharedrive
    # echo "Changing Hostname"
    # hostname "flux-"
    # echo "flux-" > /etc/hostname
    instanceid=$(curl -s http://169.254.169.254/latest/meta-data/instance-id | sed 's/i-//g')
    hostnamectl set-hostname "flux-$${instanceid}"
    echo "flux-$${instanceid}" > /etc/hostname
    hostname -F /etc/hostname
    echo "Hello I am hostname $(hostname)"
  USERDATA

  interfaces = ["ec2"]
  interface_vpc_endpoints = {
    "ec2" = {
      name                = "ec2"
      security_group_ids  = [module.vpc.vpc_default_security_group_id, module.security_group.id]
      subnet_ids          = module.subnets.private_subnet_ids
      policy              = null
      private_dns_enabled = true
    }
  }
}