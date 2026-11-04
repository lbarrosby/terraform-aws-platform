include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/eks-cluster.hcl"
  expose = true
}

inputs = {
  kubernetes_version    = "1.34"
  log_retention_in_days = 365

  admin_principal_arns = [
    "arn:aws:iam::222222222222:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_PlatformAdmin_0000000000000000",
    "arn:aws:iam::222222222222:role/terraform-platform",
  ]

  addon_overrides = {
    coredns = {
      configuration_values = "{\"replicaCount\":3,\"podDisruptionBudget\":{\"enabled\":true,\"maxUnavailable\":1}}"
    }
  }

  system_node_group = {
    instance_types = ["m7i.large", "m6i.large"]
    min_size       = 3
    desired_size   = 3
    max_size       = 5
  }
}
