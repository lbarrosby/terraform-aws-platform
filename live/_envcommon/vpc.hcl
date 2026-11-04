locals {
  source_url = "git::https://github.com/lbarrosby/terraform-aws-platform.git//modules/vpc"
  version    = "vpc-v1.0.0"
}

terraform {
  source = "${local.source_url}?ref=${local.version}"
}
