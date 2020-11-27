terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      region = "us-east-1"
    }
  }
  backend "s3" {
    bucket = "880ba170-1f3b-5bdd-9b8f-fc1e7c1e7baa-backend"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}


# Circleci configuration
provider "aws" {
  region = "us-east-1"
}

provider "template" {
}

resource "random_uuid" "randomid" {}


resource "aws_iam_user" "circleci" {
  name = "circleci-user"
  path = "/system/"
}

resource "aws_iam_access_key" "circleci" {
  user = aws_iam_user.circleci.name
}

resource "local_file" "circle_credentials" {
  filename = "tmp/circleci_credentials"
  content  = "${aws_iam_access_key.circleci.id}\n${aws_iam_access_key.circleci.secret}"
}

# Create the VPC to create the instance
module "network" {
  source            = "git@github.com:dbgoytia/networks-tf.git"
  vpc_cidr_block    = "10.0.0.0/16"
  cidr_block_subnet = "10.0.1.0/24"
}

# Deploy the instance with encypted root device
module "instances" {
  source                   = "git@github.com:dbgoytia/instances-tf.git"
  instance-type            = "t2.micro"
  ssh-key-arn              = "arn:aws:secretsmanager:us-east-1:779136181681:secret:dgoytia-ssh-key-2-6JJZH2"
  key_pair_name            = "dgoytia"
  monitoring               = true
  servers-count            = 1
  bootstrap_scripts_bucket = "bootstrap-scripts-ssa"
  bootstrap_script_key     = "networking-performance-benchmarking/ipref.sh"
  vpc_id                   = module.network.VPC_ID
  subnet_id                = module.network.SUBNET_ID
}

# Create the alarm for CPU utilization
resource "aws_cloudwatch_metric_alarm" "foobar" {
  alarm_name                = "terraform-test-foobar5"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []
}

resource "aws_sns_topic" "alarm" {
  name = "alarms-topic"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint diego.canizales1995@gmail.com"
  }
}
