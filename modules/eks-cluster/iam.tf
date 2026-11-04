################################################################################
# EBS CSI driver (Pod Identity)
################################################################################

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    sid     = "EKSPodIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name_prefix          = "${substr(var.name, 0, 24)}-ebs-csi-"
  description          = "EBS CSI controller for EKS cluster ${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.pod_identity_trust.json
  max_session_duration = 3600

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
