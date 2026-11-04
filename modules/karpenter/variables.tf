variable "cluster_name" {
  description = "EKS cluster name (output of the eks-cluster module)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,48}$", var.cluster_name))
    error_message = "cluster_name must be lowercase, max 49 chars (the node role name is <cluster>-karpenter-node)."
  }
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint, passed to the controller to skip discovery."
  type        = string
}

variable "namespace" {
  description = "Namespace for the Karpenter controller."
  type        = string
  default     = "kube-system"
}

variable "service_account" {
  description = "Service account used by the controller (bound through Pod Identity)."
  type        = string
  default     = "karpenter"
}

variable "install_helm_release" {
  description = "Install the Karpenter chart. Set to false when the controller is deployed by GitOps and only the AWS side is wanted here."
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "Karpenter chart/controller version. Read the upgrade guide before bumping minors."
  type        = string
  # renovate: datasource=docker depName=public.ecr.aws/karpenter/karpenter
  default = "1.15.1"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "chart_version must be a plain SemVer (e.g. 1.15.1)."
  }
}

variable "controller_replicas" {
  description = "Controller replicas. Two gives leader election failover across system nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.controller_replicas >= 1 && var.controller_replicas <= 3
    error_message = "controller_replicas must be between 1 and 3."
  }
}

variable "controller_node_selector" {
  description = "Node selector for the controller. Matches the system node group label set by the eks-cluster module."
  type        = map(string)
  default = {
    "platform.io/node-role" = "system"
  }
}

variable "helm_values" {
  description = "Extra YAML values merged after the module defaults for the Karpenter chart."
  type        = list(string)
  default     = []
}

variable "create_default_node_pool" {
  description = "Install the default NodePool and EC2NodeClass (local chart). Requires install_helm_release."
  type        = bool
  default     = true
}

variable "node_pool" {
  description = "Settings for the default NodePool."
  type = object({
    name                 = optional(string, "default")
    capacity_types       = optional(list(string), ["spot", "on-demand"])
    architectures        = optional(list(string), ["amd64", "arm64"])
    instance_categories  = optional(list(string), ["c", "m", "r"])
    instance_generation  = optional(number, 5)
    cpu_limit            = optional(number, 200)
    memory_limit_gib     = optional(number, 800)
    consolidation_policy = optional(string, "WhenEmptyOrUnderutilized")
    consolidate_after    = optional(string, "1m")
    expire_after         = optional(string, "720h")
    disruption_budget    = optional(string, "10%")
    weight               = optional(number, 10)
  })
  default = {}

  validation {
    condition     = length(var.node_pool.capacity_types) > 0 && alltrue([for c in var.node_pool.capacity_types : contains(["spot", "on-demand", "reserved"], c)])
    error_message = "capacity_types must be a non-empty subset of spot, on-demand, reserved."
  }

  validation {
    condition     = alltrue([for a in var.node_pool.architectures : contains(["amd64", "arm64"], a)])
    error_message = "architectures must be amd64 and/or arm64."
  }

  validation {
    condition     = contains(["WhenEmpty", "WhenEmptyOrUnderutilized"], var.node_pool.consolidation_policy)
    error_message = "consolidation_policy must be WhenEmpty or WhenEmptyOrUnderutilized."
  }

  validation {
    condition     = var.node_pool.cpu_limit > 0 && var.node_pool.memory_limit_gib > 0
    error_message = "NodePool limits must be positive; unlimited pools are how bills happen."
  }

  validation {
    condition     = can(regex("^([0-9]+(s|m|h))+$|^Never$", var.node_pool.expire_after)) && can(regex("^([0-9]+(s|m|h))+$|^Never$", var.node_pool.consolidate_after))
    error_message = "expire_after and consolidate_after must be durations like 30s, 5m, 720h or Never."
  }
}

variable "node_class" {
  description = "Settings for the default EC2NodeClass."
  type = object({
    name                = optional(string, "default")
    ami_alias           = optional(string, "al2023@latest")
    root_volume_gib     = optional(number, 50)
    discovery_tag_value = optional(string)
  })
  default = {}

  validation {
    condition     = can(regex("^(al2023|bottlerocket|al2)@(latest|v[0-9.]+)$", var.node_class.ami_alias))
    error_message = "ami_alias must look like al2023@latest or bottlerocket@v1.40.0. Pin a version in production."
  }

  validation {
    condition     = var.node_class.root_volume_gib >= 20
    error_message = "root_volume_gib must be at least 20."
  }
}

variable "tags" {
  description = "Tags for AWS resources; also propagated to EC2 instances launched by the default EC2NodeClass."
  type        = map(string)
  default     = {}
}
