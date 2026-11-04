# Complete example

VPC + EKS + Karpenter + one Pod Identity workload role, wired the way a live environment would be.

```bash
terraform init
terraform plan -var 'admin_principal_arns=["arn:aws:iam::111111111111:role/PlatformAdmin"]'
```

Notes:

- `nat_gateway_mode = "single"` and `deletion_protection = false` keep the example cheap and disposable. Do not copy those two into production.
- The `helm` provider authenticates with `aws eks get-token`, so the identity running Terraform needs an access entry (either in `admin_principal_arns` or through `enable_cluster_creator_admin_permissions`, which the example turns on when no admin is given).
- `tests/complete.tftest.hcl` plans the whole composition with mocked providers. It is what catches interface drift between modules in CI.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.71 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.3 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.71 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_app_role"></a> [app\_role](#module\_app\_role) | ../../modules/pod-identity-role | n/a |
| <a name="module_eks"></a> [eks](#module\_eks) | ../../modules/eks-cluster | n/a |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | ../../modules/karpenter | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../modules/vpc | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy_document.app_bucket_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_principal_arns"></a> [admin\_principal\_arns](#input\_admin\_principal\_arns) | Roles that get cluster admin through access entries. | `list(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name for the VPC and cluster. | `string` | `"plat-example-use1"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region. | `string` | `"us-east-1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addon_versions"></a> [addon\_versions](#output\_addon\_versions) | Resolved managed add-on versions. |
| <a name="output_app_role_arn"></a> [app\_role\_arn](#output\_app\_role\_arn) | Pod Identity role for the sample workload. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name. |
| <a name="output_karpenter_node_role"></a> [karpenter\_node\_role](#output\_karpenter\_node\_role) | IAM role used by Karpenter nodes. |
| <a name="output_kubeconfig_command"></a> [kubeconfig\_command](#output\_kubeconfig\_command) | Command to configure kubectl. |
<!-- END_TF_DOCS -->
