################################################################################
# Cluster
################################################################################

variable "name" {
  description = "Cluster name. Also used as prefix for IAM roles, KMS alias and the Karpenter discovery tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,37}[a-z0-9]$", var.name))
    error_message = "name must be 4-39 chars, lowercase alphanumerics and hyphens, starting with a letter."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes minor version (e.g. \"1.34\"). Upgrades are one minor at a time; bump it explicitly."
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must be a minor version string such as \"1.34\"."
  }
}

variable "support_type" {
  description = "EKS upgrade policy. STANDARD fails loudly at end of standard support instead of silently billing EXTENDED support."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXTENDED"], var.support_type)
    error_message = "support_type must be STANDARD or EXTENDED."
  }
}

variable "deletion_protection" {
  description = "Enable EKS deletion protection on the cluster."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC where the cluster and nodes live."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must look like vpc-xxxxxxxx."
  }
}

variable "subnet_ids" {
  description = "Private subnets for the system node group (and for the control plane ENIs when control_plane_subnet_ids is empty). Use at least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Provide at least two subnets in different AZs."
  }
}

variable "control_plane_subnet_ids" {
  description = "Dedicated subnets for the control plane cross-account ENIs (e.g. small intra subnets). Defaults to subnet_ids."
  type        = list(string)
  default     = []
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly. Private access is always on."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Required (and must not be 0.0.0.0/0) when endpoint_public_access is true."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.endpoint_public_access_cidrs : can(cidrnetmask(c))])
    error_message = "All entries must be valid IPv4 CIDRs."
  }

  validation {
    condition     = !var.endpoint_public_access || (length(var.endpoint_public_access_cidrs) > 0 && !contains(var.endpoint_public_access_cidrs, "0.0.0.0/0"))
    error_message = "A public endpoint needs an explicit allow list; 0.0.0.0/0 is not accepted."
  }
}

################################################################################
# Logging and encryption
################################################################################

variable "enabled_log_types" {
  description = "Control plane log types shipped to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition     = alltrue([for t in var.enabled_log_types : contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], t)])
    error_message = "Allowed values: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "log_retention_in_days" {
  description = "Retention for the control plane log group."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a value accepted by CloudWatch Logs."
  }
}

variable "kms_key_arn" {
  description = "Existing KMS key for envelope encryption of Kubernetes secrets. When null a dedicated key with rotation is created."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN."
  }
}

variable "kms_key_administrators" {
  description = "IAM principals allowed to administer the module-managed KMS key. Defaults to the caller identity."
  type        = list(string)
  default     = []
}

################################################################################
# Access
################################################################################

variable "admin_principal_arns" {
  description = "IAM role/user ARNs granted AmazonEKSClusterAdminPolicy through access entries (typically the platform team SSO role and the CI role)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for a in var.admin_principal_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(role|user)/", a))])
    error_message = "admin_principal_arns must be IAM role or user ARNs."
  }
}

variable "access_entries" {
  description = "Additional access entries, passed through to the upstream module (same schema)."
  type = map(object({
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant cluster admin to the identity running Terraform. Prefer admin_principal_arns; this exists for bootstrap."
  type        = bool
  default     = false
}

variable "enable_irsa" {
  description = "Create the IAM OIDC provider for IRSA. Off by default: workloads use EKS Pod Identity."
  type        = bool
  default     = false
}

################################################################################
# System node group
################################################################################

variable "system_node_group" {
  description = "Managed node group dedicated to cluster-critical pods (CoreDNS, Karpenter, CSI controllers). Tainted with CriticalAddonsOnly so application pods land on Karpenter capacity."
  type = object({
    instance_types = optional(list(string), ["m7i.large", "m6i.large"])
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = optional(number, 2)
    max_size       = optional(number, 4)
    desired_size   = optional(number, 2)
    disk_size_gib  = optional(number, 50)
    labels         = optional(map(string), {})
    taint          = optional(bool, true)
  })
  default = {}

  validation {
    condition     = var.system_node_group.min_size >= 2 && var.system_node_group.min_size <= var.system_node_group.desired_size && var.system_node_group.desired_size <= var.system_node_group.max_size
    error_message = "system_node_group requires 2 <= min_size <= desired_size <= max_size."
  }

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.system_node_group.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }

  validation {
    condition     = startswith(var.system_node_group.ami_type, "AL2023_") || startswith(var.system_node_group.ami_type, "BOTTLEROCKET_")
    error_message = "Only AL2023 and Bottlerocket AMI types are supported."
  }

  validation {
    condition     = var.system_node_group.disk_size_gib >= 20
    error_message = "disk_size_gib must be at least 20."
  }
}

################################################################################
# Add-ons
################################################################################

variable "addons_most_recent" {
  description = "Resolve add-on versions to the most recent build for the Kubernetes version instead of the EKS default build."
  type        = bool
  default     = false
}

variable "addon_overrides" {
  description = "Per add-on overrides for the managed core add-ons. Pin `version` to freeze an add-on; `configuration_values` is a JSON string."
  type = map(object({
    version              = optional(string)
    configuration_values = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.addon_overrides) : contains(["vpc-cni", "coredns", "kube-proxy", "eks-pod-identity-agent", "aws-ebs-csi-driver"], k)])
    error_message = "addon_overrides keys must be one of: vpc-cni, coredns, kube-proxy, eks-pod-identity-agent, aws-ebs-csi-driver."
  }

  validation {
    condition     = alltrue([for v in values(var.addon_overrides) : v.configuration_values == null || can(jsondecode(v.configuration_values))])
    error_message = "configuration_values must be valid JSON."
  }
}

variable "enable_ebs_csi_driver" {
  description = "Install aws-ebs-csi-driver with a Pod Identity role."
  type        = bool
  default     = true
}

variable "vpc_cni_prefix_delegation" {
  description = "Enable prefix delegation on the VPC CNI (higher pod density, fewer ENI calls)."
  type        = bool
  default     = true
}

################################################################################
# Misc
################################################################################

variable "karpenter_discovery" {
  description = "Tag the node security group with karpenter.sh/discovery=<name> so EC2NodeClass can select it."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource. Merged on top of the module default tags."
  type        = map(string)
  default     = {}
}
