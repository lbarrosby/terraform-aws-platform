include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/karpenter.hcl"
  expose = true
}

inputs = {
  node_pool = {
    capacity_types   = ["spot", "on-demand"]
    cpu_limit        = 64
    memory_limit_gib = 256
  }
}
