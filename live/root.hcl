# Root configuration included by every unit.
# Hierarchy: <account>/account.hcl -> <region>/region.hcl -> <env>/env.hcl -> <unit>/terragrunt.hcl

locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  region  = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals

  name = "${local.account.org_prefix}-${local.env.environment}-${local.region.region_short}"

  default_tags = {
    "platform:environment" = local.env.environment
    "platform:account"     = local.account.account_name
    "platform:owner"       = "platform-team"
    "platform:repository"  = "lbarrosby/terraform-aws-platform"
    "platform:unit"        = path_relative_to_include()
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "${local.account.org_prefix}-tfstate-${local.account.account_id}-${local.region.aws_region}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region.aws_region
    encrypt      = true
    use_lockfile = true

    assume_role = {
      role_arn = local.account.terraform_role_arn
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    provider "aws" {
      region              = "${local.region.aws_region}"
      allowed_account_ids = ["${local.account.account_id}"]

      assume_role {
        role_arn     = "${local.account.terraform_role_arn}"
        session_name = "terragrunt"
      }

      default_tags {
        tags = ${jsonencode(local.default_tags)}
      }
    }
  EOT
}

inputs = {
  name = local.name
  tags = local.default_tags
}
