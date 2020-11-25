terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      region = "us-west-2"
    }
  }
  backend "s3" {
    bucket = "6c4273bb-8500-0a06-a243-7d9480f2d23f-backend"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}


# Circleci configuration
provider "aws" {
  region = "us-west-2"
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