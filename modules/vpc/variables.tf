variable "name" {
  description = "VPC name, also used as prefix for subnets, route tables and endpoints."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,40}$", var.name))
    error_message = "name must be 3-41 chars of lowercase alphanumerics and hyphens."
  }
}

variable "cidr" {
  description = "VPC IPv4 CIDR. /16 to /20; subnets are carved automatically."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.cidr)) && tonumber(split("/", var.cidr)[1]) >= 16 && tonumber(split("/", var.cidr)[1]) <= 20
    error_message = "cidr must be a valid IPv4 CIDR between /16 and /20."
  }
}

variable "az_count" {
  description = "Number of AZs to spread subnets over. Ignored when azs is set."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "azs" {
  description = "Explicit AZ names. Prefer zone IDs consistency across accounts when sharing subnets."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.azs) == 0 || (length(var.azs) >= 2 && length(var.azs) <= 4)
    error_message = "azs must be empty or contain 2 to 4 AZs."
  }
}

variable "nat_gateway_mode" {
  description = "\"one_per_az\" (HA, production), \"single\" (cheaper, non-prod) or \"none\"."
  type        = string
  default     = "one_per_az"

  validation {
    condition     = contains(["one_per_az", "single", "none"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be one_per_az, single or none."
  }
}

variable "eks_cluster_names" {
  description = "Clusters that will use this VPC. Adds kubernetes.io/cluster/<name>=shared to private and public subnets."
  type        = list(string)
  default     = []
}

variable "karpenter_discovery_tag" {
  description = "Value for the karpenter.sh/discovery tag on private subnets (usually the cluster name). Null disables the tag."
  type        = string
  default     = null
}

variable "enable_flow_logs" {
  description = "Ship VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_logs_retention_in_days" {
  description = "Retention for the flow log group."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_in_days)
    error_message = "flow_logs_retention_in_days must be a value accepted by CloudWatch Logs."
  }
}

variable "vpc_endpoints" {
  description = "VPC endpoints to create. s3 is a gateway endpoint (free); the rest are interface endpoints billed per AZ-hour. Empty list disables."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for e in var.vpc_endpoints : contains(["s3", "ecr.api", "ecr.dkr", "sts", "ec2", "logs", "ssm", "ssmmessages", "ec2messages", "elasticloadbalancing", "kms"], e)])
    error_message = "Unsupported endpoint. Allowed: s3, ecr.api, ecr.dkr, sts, ec2, logs, ssm, ssmmessages, ec2messages, elasticloadbalancing, kms."
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
