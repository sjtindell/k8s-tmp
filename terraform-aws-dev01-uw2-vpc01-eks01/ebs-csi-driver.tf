locals {
  ebs_csi_driver_service_account_name      = "ebs-csi-driver-aws"
}

module "iam_assumable_role_ebs_csi_driver" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 4.0"

  create_role                   = true
  role_name                     = "ebs-csi-driver-aws"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.ebs_csi_driver.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:${local.ebs_csi_driver_service_account_name}"]
}

resource "aws_iam_policy" "ebs_csi_driver" {
  name_prefix = "ebs-csi-driver-aws"
  description = "EKS ebs-csi-driver-aw policy for cluster ${module.eks.cluster_id}"
  policy      = data.aws_iam_policy_document.ebs_csi_driver.json
}

data "aws_iam_policy_document" "ebs_csi_driver" {
  statement {
    sid    = "ebsCsiDriverAll"
    effect = "Allow"

    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ebsCsiDriverCreateTag"
    effect = "Allow"

    actions = [
      "ec2:CreateTags"
    ]

    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = [
        "CreateVolume",
        "CreateSnapshot"
      ]
    }
  }

  statement {
    sid    = "ebsCsiDriverDeleteTag"
    effect = "Allow"

    actions = [
      "ec2:DeleteTags"
    ]

    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]
  }

  statement {
    sid    = "ebsCsiDriverCreateVolume0"
    effect = "Allow"

    actions = [
      "ec2:CreateVolume"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ebsCsiDriverCreateVolume1"
    effect = "Allow"

    actions = [
      "ec2:CreateVolume"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    sid    = "ebsCsiDriverCreateVolume2"
    effect = "Allow"

    actions = [
      "ec2:CreateVolume"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    sid    = "ebsCsiDriverDeleteVolume0"
    effect = "Allow"

    actions = [
      "ec2:DeleteVolume"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ebsCsiDriverDeleteVolume1"
    effect = "Allow"

    actions = [
      "ec2:DeleteVolume"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    sid    = "ebsCsiDriverDeleteVolume2"
    effect = "Allow"

    actions = [
      "ec2:DeleteVolume"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    sid    = "ebsCsiDriverDeleteSnapshot0"
    effect = "Allow"

    actions = [
      "ec2:DeleteSnapshot"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
      values   = ["*"]
    }
  }

  statement {
    sid    = "ebsCsiDriverDeleteSnapshot1"
    effect = "Allow"

    actions = [
      "ec2:DeleteSnapshot"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}
