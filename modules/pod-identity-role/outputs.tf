output "role_arn" {
  description = "ARN of the workload role."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the workload role."
  value       = aws_iam_role.this.name
}

output "association_ids" {
  description = "Pod Identity association IDs keyed like var.associations."
  value       = { for k, v in aws_eks_pod_identity_association.this : k => v.association_id }
}
