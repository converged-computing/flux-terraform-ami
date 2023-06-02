# Generate a packer build for an AMI (Amazon Image)

# This will allow us to use AWS plugins
packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}


# These variables can be referenced in our recipes below, and available
# on the command line of "packer build -var name=value"
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "ssh_username" {
  type    = string
  default = "rocky"
}

variable "instance_type" {
  type    = string
  default = "m4.large"
}

variable "source_ami" {
  type    = string
  default = "ami-09d91a87b002fc97a"
}

# "timestamp" template function replacement for image naming
# This is so us of the future can remember when images were built
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

# This is the packer recipe for the flux-compute ami
# Note that AWS credentials come from the environment and do not
# need to be provided directly here
# https://www.packer.io/docs/templates/hcl_templates/blocks/source
source "amazon-ebs" "flux-login" {
  ami_name        = "packer-aws-flux-login-${local.timestamp}"
  ami_description = "A flux-login node with Rocky Linux intended to run on AWS EC2"
  instance_type   = "${var.instance_type}"
  region          = "${var.region}"
  ssh_username    = "${var.ssh_username}"

  # Note we can use source_ami_filter to get a match instead of an exact id
  source_ami = "${var.source_ami}"
}

build {
  name    = "flux-login"
  sources = ["source.amazon-ebs.flux-login"]

  # This allows us to store shared logic, plus custom logic for the login node
  provisioner "shell" {
    scripts = ["../shared/install-flux.sh", "./flux-login-builder-startup-script.sh"]
  }
}