data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  tags = merge(
    {
      "platform:module"     = "vpc"
      "platform:managed-by" = "terraform"
    },
    var.tags,
  )

  azs = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Layout for a /16 (scales down proportionally up to /20):
  #   private  /19 per AZ  -> first half of the range, where pods and nodes live
  #   public   /24 per AZ  -> load balancers and NAT gateways
  #   intra    /24 per AZ  -> EKS control plane ENIs, no route to the internet
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.cidr, 3, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, 128 + i)]
  intra_subnets   = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, 144 + i)]

  cluster_tags = { for c in var.eks_cluster_names : "kubernetes.io/cluster/${c}" => "shared" }

  interface_endpoints = [for e in var.vpc_endpoints : e if e != "s3"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = var.name
  cidr = var.cidr
  azs  = local.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway     = var.nat_gateway_mode != "none"
  single_nat_gateway     = var.nat_gateway_mode == "single"
  one_nat_gateway_per_az = var.nat_gateway_mode == "one_per_az"

  map_public_ip_on_launch       = false
  manage_default_security_group = true
  manage_default_network_acl    = true
  manage_default_route_table    = true

  public_subnet_tags = merge(local.cluster_tags, {
    "kubernetes.io/role/elb" = "1"
  })

  private_subnet_tags = merge(
    local.cluster_tags,
    { "kubernetes.io/role/internal-elb" = "1" },
    var.karpenter_discovery_tag != null ? { "karpenter.sh/discovery" = var.karpenter_discovery_tag } : {},
  )

  enable_flow_log                                 = var.enable_flow_logs
  create_flow_log_cloudwatch_log_group            = var.enable_flow_logs
  create_flow_log_cloudwatch_iam_role             = var.enable_flow_logs
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_logs_retention_in_days
  flow_log_max_aggregation_interval               = 60

  tags = local.tags
}

module "endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.7.3"

  create = length(var.vpc_endpoints) > 0

  vpc_id = module.vpc.vpc_id

  create_security_group      = length(local.interface_endpoints) > 0
  security_group_name_prefix = "${var.name}-vpce-"
  security_group_description = "HTTPS from inside ${var.name} to interface endpoints"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = merge(
    contains(var.vpc_endpoints, "s3") ? {
      s3 = {
        service         = "s3"
        service_type    = "Gateway"
        route_table_ids = concat(module.vpc.private_route_table_ids, module.vpc.intra_route_table_ids)
        tags            = { Name = "${var.name}-s3" }
      }
    } : {},
    {
      for e in local.interface_endpoints : replace(e, ".", "_") => {
        service             = e
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
        tags                = { Name = "${var.name}-${replace(e, ".", "-")}" }
      }
    },
  )

  tags = local.tags
}
