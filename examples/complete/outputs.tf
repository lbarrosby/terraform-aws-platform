output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Command to configure kubectl."
  value       = module.eks.kubeconfig_command
}

output "addon_versions" {
  description = "Resolved managed add-on versions."
  value       = module.eks.addon_versions
}

output "karpenter_node_role" {
  description = "IAM role used by Karpenter nodes."
  value       = module.karpenter.node_iam_role_name
}

output "app_role_arn" {
  description = "Pod Identity role for the sample workload."
  value       = module.app_role.role_arn
}
