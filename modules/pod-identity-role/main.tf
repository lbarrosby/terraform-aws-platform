data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  tags = merge(
    {
      "platform:module"     = "pod-identity-role"
      "platform:managed-by" = "terraform"
      "platform:cluster"    = var.cluster_name
    },
    var.tags,
  )

  cluster_arn = "arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
}

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "EKSPodIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    dynamic "condition" {
      for_each = var.restrict_to_cluster ? [1] : []
      content {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }

    dynamic "condition" {
      for_each = var.restrict_to_cluster ? [1] : []
      content {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [local.cluster_arn]
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  path                 = var.path
  description          = "Pod Identity role for ${join(", ", [for a in values(var.associations) : "${a.namespace}/${a.service_account}"])} on ${var.cluster_name}"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn

  tags = local.tags
}

data "aws_iam_policy_document" "inline" {
  count = length(var.policy_documents) > 0 ? 1 : 0

  source_policy_documents = var.policy_documents
}

resource "aws_iam_role_policy" "this" {
  count = length(var.policy_documents) > 0 ? 1 : 0

  name   = "workload"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline[0].json
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.managed_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_eks_pod_identity_association" "this" {
  for_each = var.associations

  cluster_name    = var.cluster_name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = aws_iam_role.this.arn

  tags = local.tags
}
