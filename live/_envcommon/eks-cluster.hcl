locals {
  source_url = "git::https://github.com/lbarrosby/terraform-aws-platform.git//modules/eks-cluster"
  version    = "eks-cluster-v1.0.0"
}

terraform {
  source = "${local.source_url}?ref=${local.version}"
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../vpc"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
    intra_subnet_ids   = ["subnet-00000000000000004", "subnet-00000000000000005", "subnet-00000000000000006"]
  }
}

inputs = {
  vpc_id                   = dependency.vpc.outputs.vpc_id
  subnet_ids               = dependency.vpc.outputs.private_subnet_ids
  control_plane_subnet_ids = dependency.vpc.outputs.intra_subnet_ids
}
