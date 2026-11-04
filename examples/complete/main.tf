locals {
  tags = {
    "platform:environment" = "example"
    "platform:owner"       = "platform-team"
    "platform:repository"  = "lbarrosby/terraform-aws-platform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name             = var.name
  cidr             = "10.42.0.0/16"
  az_count         = 3
  nat_gateway_mode = "single"

  eks_cluster_names       = [var.name]
  karpenter_discovery_tag = var.name

  vpc_endpoints = ["s3", "ecr.api", "ecr.dkr", "sts", "ec2"]
}

module "eks" {
  source = "../../modules/eks-cluster"

  name                = var.name
  kubernetes_version  = "1.34"
  deletion_protection = false

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.intra_subnet_ids

  admin_principal_arns                     = var.admin_principal_arns
  enable_cluster_creator_admin_permissions = length(var.admin_principal_arns) == 0

  system_node_group = {
    instance_types = ["m7i.large", "m6i.large"]
    min_size       = 2
    desired_size   = 2
    max_size       = 3
  }
}

module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint

  node_pool = {
    cpu_limit        = 100
    memory_limit_gib = 400
  }
}

data "aws_iam_policy_document" "app_bucket_read" {
  statement {
    sid       = "ReadArtifacts"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::example-artifacts", "arn:aws:s3:::example-artifacts/*"]
  }
}

module "app_role" {
  source = "../../modules/pod-identity-role"

  name         = "${var.name}-shop-api"
  cluster_name = module.eks.cluster_name

  associations = {
    api = {
      namespace       = "shop"
      service_account = "shop-api"
    }
  }

  policy_documents = [data.aws_iam_policy_document.app_bucket_read.json]
}
