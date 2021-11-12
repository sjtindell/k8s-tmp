provider "aws" {
  region = "us-west-2"
}

module "common_tags" {
  source = "../terraform-modules/aws-tags"
  owner = "techops"
  environment = "network"
  cloud-provider = "aws"
  region = "us-west-2"
  service = "vpc"
  project = "techops"
}

locals {
  name = "my-vpc"
  region = "us-west-2"
  tags  = merge(
    module.common_tags.tags,
    {},
  )
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.7.0"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  database_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  database_subnet_suffix = "private-persistent"

  enable_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags

  vpc_tags = {
    name = "vpc-name"
  }
}

module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "uw2.dev01.aws.zuora.com" = {
      comment = "uw2.dev01.aws.zuora.com (external)"
    }

    "uw2.dev01.aws.zuora" = {
      comment = "uw2.dev01.aws.zuora (internal)"
      vpc = [
        {
          vpc_id = module.vpc.vpc_id
        }
      ]
    }
  }

  tags = merge(
    local.tags,
    {
     "terraform"= "true"
    }
  )
}