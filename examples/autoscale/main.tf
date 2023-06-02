
# VARIABLES # for you to edit!

locals {
  name          = "flux"
  pwd           = basename(path.cwd)
  region        = "us-east-1"
  ami           = "ami-0ff535566e7c13e8c"
  instance_type = "m4.large"
  vpc_cidr      = "10.0.0.0/16"
  key_name      = "dinosaur"

  # Must be larger than ami
  volume_size = 30

  # Set autoscaling to consistent size so we don't scale for now
  min_size     = 6
  max_size     = 6
  desired_size = 6

  cidr_block_a = "10.0.1.0/24"
  cidr_block_b = "10.0.2.0/24"
  cidr_block_c = "10.0.3.0/24"
}

# Example queries to get public ip addresses or private DNS names
# aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=flux-selector" | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress
# aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=flux-selector" | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.49.0"
    }
  }
}

data "template_file" "startup_script" {
  template = <<EOF
#!/bin/bash

# Install AWS client
python3 -m pip install awscli

# Wait for the count to be up
while [[ $(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=${local.name}-selector" | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName | wc -l) -ne ${local.desired_size} ]]
do
   echo "Desired count not reached, sleeping."
   sleep 10
done
found_count=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=${local.name}-selector" | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress | wc -l)
echo "Desired count $found_count is reached"

# Update the flux config files with our hosts - we need the ones from hostname
hosts=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=${local.name}-selector" | jq -r .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName)

# Hack them together into comma separated list
NODELIST=""
for host in $hosts; do
   if [[ "$NODELIST" == "" ]]; then
      NODELIST=$host
   else
      NODELIST=$NODELIST,$host   
   fi
done

# Replace in hostlist
sed -i 's/NODELIST/"'"$NODELIST"'"/g' /usr/local/etc/flux/system/conf.d/system.toml

# Delete flux manager line for now
gawk -i inplace '!/FLUXMANGER/' /usr/local/etc/flux/system/conf.d/system.toml

# Generate the flux resource file
flux R encode --hosts=$NODELIST > /usr/local/etc/flux/system/R

# Make the run directories in case not made yet
mkdir -p /run/flux
chown -R flux /run/flux

# See the README.md for commands how to set this manually without systemd
systemctl restart flux.service
  EOF
}

provider "aws" {
  region = local.region
}

# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.name}-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.cidr_block_a
  availability_zone = "${local.region}a"

  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "resource-name"

  tags = {
    Name = "${local.name}-subnet-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.cidr_block_b
  availability_zone = "${local.region}b"

  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "resource-name"

  tags = {
    Name = "${local.name}-subnet-public-b"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.cidr_block_c
  availability_zone = "${local.region}c"

  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "resource-name"

  tags = {
    Name = "${local.name}-subnet-public-c"
  }
}

resource "aws_internet_gateway" "main_gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-main-gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gateway.id
  }

  tags = {
    Name = "${local.name}-public-route-table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "security_group" {
  name   = "${local.name}-security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow http from everywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = [local.cidr_block_a, local.cidr_block_b, local.cidr_block_c]
  }

  # This could be scoped better to internal instances
  ingress {
    description = "Allow http on port 8050 for flux"
    from_port   = 8050
    to_port     = 8050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ssh from everywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "icmp"
    from_port   = 8
    to_port     = 0
    description = "Allow pings"
  }

  egress {
    description = "Allow outgoing traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-security-group"
  }
}

resource "aws_lb" "load_balancer" {
  name               = "${local.name}-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id, aws_subnet.public_c.id]
}

resource "aws_lb_listener" "load_balance_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "${local.name}-target-group"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
}


# Create an IAM instance profile to allow using the awscli

resource "aws_iam_policy" "ec2_policy" {
  name        = "${local.name}-ec2-policy"
  path        = "/"
  description = "Policy to allow listing instances"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "ec2:DescribeInstances",
        "ec2:DescribeImages",
        "ec2:DescribeTags",
        "ec2:DescribeSnapshots"
      ],
      "Resource" : "*"
    }]
  })
}

# The trust policy specifies who or what can assume the role
# The permission policy specify the actions available on what resources
resource "aws_iam_role" "ec2_role" {
  name = "${local.name}-ec2-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" = "Allow",
      "Action" = "sts:AssumeRole",
      "Sid"    = ""
      "Principal" = {
        "Service" = "ec2.amazonaws.com"
      }
    }],
  })
}


# Attach the role to the policy file
resource "aws_iam_policy_attachment" "ec2_policy_role" {
  name       = "${local.name}-ec2-attachment"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = aws_iam_policy.ec2_policy.arn
}

# Create an instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_launch_template" "launch_template" {

  name = "launch_template"

  image_id      = local.ami
  instance_type = local.instance_type
  key_name      = local.key_name
  user_data     = base64encode(data.template_file.startup_script.rendered)

  # So we can use the AWS client
  iam_instance_profile {
    # arn = aws_iam_instance_profile.iam_profile.arn
    name = aws_iam_instance_profile.ec2_profile.name
  }
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = local.volume_size
      volume_type = "gp2"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.security_group.id]
  }
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name               = "${local.name}-autoscaling-group"
  max_size           = local.min_size
  min_size           = local.max_size
  health_check_type  = "ELB"
  capacity_rebalance = false

  # Make this really large so we don't check soon :)
  health_check_grace_period = 10000
  desired_capacity          = local.desired_size
  target_group_arns         = [aws_lb_target_group.target_group.arn]

  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id, aws_subnet.public_c.id]
  # default_cooldown is unset

  # These could also be selected based on the asg, e.g.,
  # "aws:autoscaling:groupName"
  # "flux-autoscaling-group"
  tag {
    key                 = "selector"
    value               = "${local.name}-selector"
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }
}
