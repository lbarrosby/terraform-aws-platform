data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  tags = merge(
    {
      "platform:module"     = "eks-cluster"
      "platform:managed-by" = "terraform"
      "platform:cluster"    = var.name
    },
    var.tags,
  )

  create_kms_key = var.kms_key_arn == null

  # Core add-ons managed by EKS. Anything else (LB controller, external-dns, ...)
  # belongs in GitOps, not here.
  core_addon_names = concat(
    ["vpc-cni", "eks-pod-identity-agent", "kube-proxy", "coredns"],
    var.enable_ebs_csi_driver ? ["aws-ebs-csi-driver"] : [],
  )

  default_addon_config = {
    "vpc-cni" = var.vpc_cni_prefix_delegation ? jsonencode({
      env = {
        ENABLE_PREFIX_DELEGATION = "true"
        WARM_PREFIX_TARGET       = "1"
      }
    }) : null
  }

  # vpc-cni and the pod identity agent must exist before nodes join, otherwise
  # the first nodes come up NotReady and pods cannot get credentials.
  before_compute = ["vpc-cni", "eks-pod-identity-agent"]

  addons = {
    for name in local.core_addon_names : name => {
      before_compute       = contains(local.before_compute, name)
      most_recent          = var.addons_most_recent
      addon_version        = coalesce(try(var.addon_overrides[name].version, null), data.aws_eks_addon_version.this[name].version)
      configuration_values = try(coalesce(try(var.addon_overrides[name].configuration_values, null), lookup(local.default_addon_config, name, null)), null)
      pod_identity_association = name == "aws-ebs-csi-driver" ? [{
        role_arn        = aws_iam_role.ebs_csi[0].arn
        service_account = "ebs-csi-controller-sa"
      }] : null
    }
  }

  admin_access_entries = {
    for arn in var.admin_principal_arns : "admin-${replace(element(split("/", arn), length(split("/", arn)) - 1), "/[^a-zA-Z0-9-]/", "-")}" => {
      principal_arn = arn
      policy_associations = {
        cluster_admin = {
          policy_arn   = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

data "aws_eks_addon_version" "this" {
  for_each = toset(local.core_addon_names)

  addon_name         = each.value
  kubernetes_version = var.kubernetes_version
  most_recent        = var.addons_most_recent
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name                = var.name
  kubernetes_version  = var.kubernetes_version
  iam_role_name       = "${substr(var.name, 0, 28)}-cluster"
  deletion_protection = var.deletion_protection

  upgrade_policy = {
    support_type = var.support_type
  }

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = length(var.control_plane_subnet_ids) > 0 ? var.control_plane_subnet_ids : var.subnet_ids

  endpoint_private_access      = true
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access ? var.endpoint_public_access_cidrs : null

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  access_entries                           = merge(local.admin_access_entries, var.access_entries)
  enable_irsa                              = var.enable_irsa

  enabled_log_types                      = var.enabled_log_types
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = var.log_retention_in_days

  create_kms_key                  = local.create_kms_key
  enable_kms_key_rotation         = true
  kms_key_deletion_window_in_days = 30
  kms_key_administrators          = var.kms_key_administrators
  kms_key_aliases                 = local.create_kms_key ? ["eks/${var.name}"] : []
  encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }

  addons = local.addons

  node_security_group_tags = var.karpenter_discovery ? {
    "karpenter.sh/discovery" = var.name
  } : {}

  eks_managed_node_groups = {
    system = {
      name            = "system"
      use_name_prefix = true

      # IAM name_prefix is capped at 38 chars; keep it bounded for long cluster names.
      iam_role_name            = "${substr(var.name, 0, 28)}-system"
      iam_role_use_name_prefix = true
      subnet_ids               = var.subnet_ids

      ami_type       = var.system_node_group.ami_type
      instance_types = var.system_node_group.instance_types
      capacity_type  = var.system_node_group.capacity_type

      min_size     = var.system_node_group.min_size
      max_size     = var.system_node_group.max_size
      desired_size = var.system_node_group.desired_size

      labels = merge(
        { "platform.io/node-role" = "system" },
        var.system_node_group.labels,
      )

      taints = var.system_node_group.taint ? {
        critical_addons_only = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      } : {}

      block_device_mappings = {
        root = {
          device_name = startswith(var.system_node_group.ami_type, "BOTTLEROCKET_") ? "/dev/xvdb" : "/dev/xvda"
          ebs = {
            volume_size           = var.system_node_group.disk_size_gib
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      update_config = {
        max_unavailable_percentage = 33
      }

      node_repair_config = {
        enabled = true
      }

      iam_role_additional_policies = {
        ssm = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  tags = local.tags
}
