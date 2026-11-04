output "controller_role_arn" {
  description = "IAM role assumed by the Karpenter controller through Pod Identity."
  value       = module.karpenter.iam_role_arn
}

output "node_iam_role_name" {
  description = "IAM role for nodes launched by Karpenter (referenced by EC2NodeClass.spec.role)."
  value       = module.karpenter.node_iam_role_name
}

output "node_iam_role_arn" {
  description = "ARN of the Karpenter node role."
  value       = module.karpenter.node_iam_role_arn
}

output "interruption_queue_name" {
  description = "SQS queue receiving spot interruption and rebalance events."
  value       = module.karpenter.queue_name
}

output "chart_version" {
  description = "Installed Karpenter version, null when the chart is managed elsewhere."
  value       = var.install_helm_release ? var.chart_version : null
}

output "default_node_pool_name" {
  description = "Name of the default NodePool, null when not created."
  value       = var.install_helm_release && var.create_default_node_pool ? var.node_pool.name : null
}
