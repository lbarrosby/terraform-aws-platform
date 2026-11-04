variable "name" {
  description = "IAM role name. Convention: <cluster>-<namespace>-<workload>."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]{1,64}$", var.name))
    error_message = "name must be a valid IAM role name (max 64 chars)."
  }
}

variable "cluster_name" {
  description = "EKS cluster the associations are created in."
  type        = string
}

variable "associations" {
  description = "Service accounts allowed to assume the role, keyed by a stable identifier."
  type = map(object({
    namespace       = string
    service_account = string
  }))

  validation {
    condition     = length(var.associations) > 0
    error_message = "At least one association is required; a role nobody can assume is dead code."
  }

  validation {
    condition = alltrue([
      for a in values(var.associations) :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", a.namespace)) && can(regex("^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$", a.service_account))
    ])
    error_message = "namespace and service_account must be valid Kubernetes names."
  }
}

variable "policy_documents" {
  description = "IAM policy documents (JSON) merged into a single inline policy. Usually the `json` of aws_iam_policy_document data sources."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for d in var.policy_documents : can(jsondecode(d))])
    error_message = "Every policy document must be valid JSON."
  }
}

variable "managed_policy_arns" {
  description = "Managed policies to attach, keyed by a static name so plans stay stable when ARNs are unknown."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for arn in values(var.managed_policy_arns) : can(regex("^arn:aws[a-z-]*:iam::([0-9]{12}|aws):policy/", arn))])
    error_message = "managed_policy_arns values must be IAM policy ARNs."
  }
}

variable "restrict_to_cluster" {
  description = "Add aws:SourceAccount and aws:SourceArn conditions so only this cluster's Pod Identity agent can assume the role."
  type        = bool
  default     = true
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary for the role."
  type        = string
  default     = null
}

variable "path" {
  description = "IAM path for the role."
  type        = string
  default     = "/"

  validation {
    condition     = can(regex("^/([a-zA-Z0-9+=,.@_-]+/)*$", var.path))
    error_message = "path must start and end with a slash."
  }
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200."
  }
}

variable "tags" {
  description = "Tags applied to the role and associations."
  type        = map(string)
  default     = {}
}
