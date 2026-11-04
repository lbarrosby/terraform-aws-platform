variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Base name for the VPC and cluster."
  type        = string
  default     = "plat-example-use1"
}

variable "admin_principal_arns" {
  description = "Roles that get cluster admin through access entries."
  type        = list(string)
  default     = []
}
