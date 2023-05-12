region                                 = "us-east-1"
key_name                               = "dinosaur"
availability_zones                     = ["us-east-1a", "us-east-1b"]
namespace                              = "flux"
stage                                  = "test"
name                                   = "cluster"
image_id                               = "ami-02eac56446a475861"
instance_type                          = "m4.large"
health_check_type                      = "EC2"
wait_for_capacity_timeout              = "10m"
max_size                               = 3
min_size                               = 3
cpu_utilization_high_threshold_percent = 80
cpu_utilization_low_threshold_percent  = 20

security_group_rules = [
  {
    type        = "egress"
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    type        = "ingress"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    type        = "ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    type        = "ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    type        = "ingress"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  },
]