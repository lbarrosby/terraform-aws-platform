# pod-identity-role

IAM role for a Kubernetes workload, bound through **EKS Pod Identity**. No OIDC provider, no service account annotations: the association lives in the EKS API.

- Trust policy for `pods.eks.amazonaws.com` (`sts:AssumeRole` + `sts:TagSession`), scoped by default with `aws:SourceAccount` and `aws:SourceArn` to the target cluster.
- Permissions from `policy_documents` (merged into one inline policy) and/or `managed_policy_arns` (map with static keys so plans stay stable when ARNs are computed).
- One association per entry in `associations`.

Session tags (`kubernetes-namespace`, `kubernetes-service-account`, `eks-cluster-name`) are set by EKS, so a single policy can use ABAC conditions such as `aws:PrincipalTag/kubernetes-namespace`.

## Usage

```hcl
data "aws_iam_policy_document" "orders" {
  statement {
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.orders.arn]
  }
}

module "orders_worker_role" {
  source = "git::https://github.com/lbarrosby/terraform-aws-platform.git//modules/pod-identity-role?ref=pod-identity-role-v1.0.0"

  name         = "plat-prod-use1-orders-worker"
  cluster_name = module.eks.cluster_name

  associations = {
    worker = { namespace = "orders", service_account = "orders-worker" }
  }

  policy_documents = [data.aws_iam_policy_document.orders.json]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.59, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.59, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eks_pod_identity_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_associations"></a> [associations](#input\_associations) | Service accounts allowed to assume the role, keyed by a stable identifier. | ```map(object({ namespace = string service_account = string }))``` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster the associations are created in. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | IAM role name. Convention: <cluster>-<namespace>-<workload>. | `string` | n/a | yes |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | Managed policies to attach, keyed by a static name so plans stay stable when ARNs are unknown. | `map(string)` | `{}` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration in seconds. | `number` | `3600` | no |
| <a name="input_path"></a> [path](#input\_path) | IAM path for the role. | `string` | `"/"` | no |
| <a name="input_permissions_boundary_arn"></a> [permissions\_boundary\_arn](#input\_permissions\_boundary\_arn) | Optional permissions boundary for the role. | `string` | `null` | no |
| <a name="input_policy_documents"></a> [policy\_documents](#input\_policy\_documents) | IAM policy documents (JSON) merged into a single inline policy. Usually the `json` of aws\_iam\_policy\_document data sources. | `list(string)` | `[]` | no |
| <a name="input_restrict_to_cluster"></a> [restrict\_to\_cluster](#input\_restrict\_to\_cluster) | Add aws:SourceAccount and aws:SourceArn conditions so only this cluster's Pod Identity agent can assume the role. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the role and associations. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_association_ids"></a> [association\_ids](#output\_association\_ids) | Pod Identity association IDs keyed like var.associations. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the workload role. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the workload role. |
<!-- END_TF_DOCS -->
