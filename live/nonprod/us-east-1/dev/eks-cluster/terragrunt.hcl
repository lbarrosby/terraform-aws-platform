include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/eks-cluster.hcl"
  expose = true
}

inputs = {
  kubernetes_version  = "1.34"
  deletion_protection = false

  admin_principal_arns = [
    "arn:aws:iam::111111111111:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_PlatformAdmin_0000000000000000",
    "arn:aws:iam::111111111111:role/terraform-platform",
  ]

  system_node_group = {
    instance_types = ["t3a.large", "t3.large"]
    min_size       = 2
    desired_size   = 2
    max_size       = 3
  }
}
