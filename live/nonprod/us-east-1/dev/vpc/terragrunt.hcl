include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vpc.hcl"
  expose = true
}

inputs = {
  cidr                    = "10.10.0.0/16"
  az_count                = 3
  nat_gateway_mode        = "single"
  eks_cluster_names       = [include.root.locals.name]
  karpenter_discovery_tag = include.root.locals.name
  vpc_endpoints           = ["s3"]
}
