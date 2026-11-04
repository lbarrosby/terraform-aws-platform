output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded cluster CA, for kubeconfig and the helm/kubernetes providers."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Additional cluster security group created by the module."
  value       = module.eks.cluster_security_group_id
}

output "cluster_primary_security_group_id" {
  description = "EKS-managed primary security group."
  value       = module.eks.cluster_primary_security_group_id
}

output "node_security_group_id" {
  description = "Shared node security group (tagged for Karpenter discovery)."
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN. Null unless enable_irsa is true."
  value       = var.enable_irsa ? module.eks.oidc_provider_arn : null
}

output "kms_key_arn" {
  description = "KMS key used for secrets envelope encryption."
  value       = local.create_kms_key ? module.eks.kms_key_arn : var.kms_key_arn
}

output "cloudwatch_log_group_name" {
  description = "Control plane log group."
  value       = module.eks.cloudwatch_log_group_name
}

output "system_node_group_iam_role_arn" {
  description = "IAM role of the system managed node group."
  value       = module.eks.eks_managed_node_groups["system"].iam_role_arn
}

output "addon_versions" {
  description = "Resolved version per managed add-on."
  value       = { for k, v in local.addons : k => v.addon_version }
}

output "ebs_csi_role_arn" {
  description = "Pod Identity role used by the EBS CSI controller."
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
}

output "kubeconfig_command" {
  description = "Convenience command to update the local kubeconfig."
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${module.eks.cluster_name}"
}
