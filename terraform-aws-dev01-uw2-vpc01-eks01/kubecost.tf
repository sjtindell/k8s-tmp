locals {
  kubecost_bucket_name = "kubecost-cost-analyzer-uw2"
}

module "kubecost_s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.kubecost_bucket_name
  acl    = "private"
}

resource "aws_spot_datafeed_subscription" "default" {
  bucket = local.kubecost_bucket_name
  prefix = "kubecost-uw2"
}

module "kubecost_iam_assumable_role_admin" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 4.0"

  create_role = true
  role_name                     = "kubecost_cost_analyzer"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.kubecost_cost_analyzer.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kubecost:kubecost-cost-analyzer"]
}

resource "aws_iam_policy" "kubecost_cost_analyzer" {
  name_prefix = "kubecost_cost_analyzer"
  description = "EKS kubecost_cost_analyzer policy for cluster ${module.eks.cluster_id}"
  policy      = data.aws_iam_policy_document.kubecost_cost_analyzer.json
}

data "aws_iam_policy_document" "kubecost_cost_analyzer" {
  
  statement {
    sid    = "kubecostBucket"
    effect = "Allow"

    actions = [
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:HeadBucket",
      "s3:HeadObject",
      "s3:List*",
      "s3:Get*"
    ]

    resources = [
      "arn:aws:s3:::${local.kubecost_bucket_name}",
      "arn:aws:s3:::${local.kubecost_bucket_name}/*",
    ]
  }
  
}