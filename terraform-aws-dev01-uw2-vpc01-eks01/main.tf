provider "aws" {
  region = "us-west-2"
}

module "common_tags" {
  source         = "../terraform-modules/aws-tags"
  owner          = "techops"
  environment    = "shared"
  cloud-provider = "aws"
  region         = "us-west-2"
  service        = "kubernetes"
  project        = "techops"
}

locals {
  cluster_name = "my-eks-cluster"
  region       = "us-west-2"
  vpc_id       = "vpc-0ed9d304f35d1f053"

  tags = merge(
    module.common_tags.tags,
    {
      eks-cluster = local.cluster_name
    },
  )
}

module "security_group_worker_ssh" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "worker-ssh-sg-${local.cluster_name}"
  description = "Security group for example usage with SSH"
  vpc_id      = local.vpc_id

  ingress_cidr_blocks = ["10.0.0.0/16"]
  ingress_rules       = ["ssh-tcp"]
}

module "security_group_worker_ingress_int" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "worker-ingress-int-sg-${local.cluster_name}"
  description = "Security group for example usage with Ingress Internal"
  vpc_id      = local.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 32081
      to_port     = 32081
      protocol    = "tcp"
      description = "worker ingress int port"
      cidr_blocks = "10.0.0.0/16"
    },
  ]
}

module "security_group_worker_ingress_ext" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "worker-ingress-ext-sg-${local.cluster_name}"
  description = "Security group for example usage with Ingress External"
  vpc_id      = local.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 32080
      to_port     = 32080
      protocol    = "tcp"
      description = "worker ingress ext port"
      cidr_blocks = "10.0.0.0/16"
    },
  ]
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name    = local.cluster_name
  cluster_version = "1.21"

  vpc_id  = local.vpc_id
  subnets = ["subnet-0018c6fd3a0ece6a1", "subnet-00ac589cd29907d98", "subnet-04f38e1ebe6bc4d6b"]

  cluster_enabled_log_types = ["api", "audit", "scheduler", "controllerManager", "authenticator"]

  cluster_log_retention_in_days = 1

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  workers_group_defaults = {
    key_name                      = "stindell"
    additional_security_group_ids = [
      module.security_group_worker_ssh.security_group_id,
      module.security_group_worker_ingress_int.security_group_id,
      module.security_group_worker_ingress_ext.security_group_id
    ]
    target_group_arns = concat(
      module.alb_ingress_int.target_group_arns,
      module.alb_ingress_ext.target_group_arns,
    )
    additional_tags = merge(
      local.tags,
      {
        key                 = "k8s.io/cluster-autoscaler/enabled"
        value               = "true"
        propagate_at_launch = true
      },
      {
        key                 = "k8s.io/cluster-autoscaler/${local.cluster_name}"
        value               = "owned"
        propagate_at_launch = true
      },
      {
        key                 = "aws-node-termination-handler/managed"
        value               = ""
        propagate_at_launch = true
      },
    )
  }

  worker_groups_launch_template = [
    {
      name          = "ng-2vpcu-4gb-on-demand-aza"
      instance_type = "t3.medium"
      asg_min_size  = 1
      asg_max_size  = 5

      subnets = ["subnet-0018c6fd3a0ece6a1"]

      kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=on-demand"

      instance_refresh_enabled             = true
      instance_refresh_instance_warmup     = 60
      metadata_http_put_response_hop_limit = 3
      update_default_version               = true
      instance_refresh_triggers            = ["tag"]

      #ebs_optimized             = true
      #root_encrypted            = true
      #root_volume_type          = "gp2"
      #root_volume_size          = "100"
    },
    {
      name          = "ng-2vpcu-4gb-on-demand-azb"
      instance_type = "t3.medium"
      asg_min_size  = 1
      asg_max_size  = 5

      subnets = ["subnet-00ac589cd29907d98"]

      kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=on-demand"

      instance_refresh_enabled             = true
      instance_refresh_instance_warmup     = 60
      metadata_http_put_response_hop_limit = 3
      update_default_version               = true
      instance_refresh_triggers            = ["tag"]
    },
    {
      name          = "ng-2vpcu-4gb-on-demand-azc"
      instance_type = "t3.medium"
      asg_min_size  = 1
      asg_max_size  = 5

      subnets = ["subnet-04f38e1ebe6bc4d6b"]

      kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=on-demand"

      instance_refresh_enabled             = true
      instance_refresh_instance_warmup     = 60
      metadata_http_put_response_hop_limit = 3
      update_default_version               = true
      instance_refresh_triggers            = ["tag"]
    },
    {
      name                    = "ng-2vcpu-8gb-spot"
      override_instance_types = ["m5.large", "m5a.large", "m5d.large", "m5ad.large"]
      spot_instance_pools     = 4
      asg_min_size            = 1
      asg_max_size            = 12

      kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=spot"

      instance_refresh_enabled             = true
      instance_refresh_instance_warmup     = 60
      metadata_http_put_response_hop_limit = 3
      update_default_version               = true
      instance_refresh_triggers            = ["tag"]
    }
  ]

  write_kubeconfig = false

  map_roles = [
    {
      rolearn  = "arn:aws:iam::364736210010:role/Zuora-Admin"
      username = "admin"
      groups   = ["system:masters"]
    }
  ]

  tags = local.tags

}

# Kubernetes
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}