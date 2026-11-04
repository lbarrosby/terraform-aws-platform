# karpenter

Karpenter for clusters built with `eks-cluster`.

- AWS side via the upstream `terraform-aws-modules/eks//modules/karpenter` submodule (`21.29.0`): controller role bound through **EKS Pod Identity** (with `aws:SourceArn` scoped to the cluster), node role with a stable name, node access entry, SQS interruption queue and EventBridge rules.
- Controller installed from `oci://public.ecr.aws/karpenter` at a pinned chart version, two replicas, pinned to the system node group (tolerates `CriticalAddonsOnly`).
- Optional default `EC2NodeClass` + `NodePool` (spot and on-demand, `c/m/r` generation > 5, amd64 + arm64, consolidation `WhenEmptyOrUnderutilized`, 30 day expiry, 10% disruption budget, hard CPU/memory limits).

The default NodePool/EC2NodeClass ship as a small local Helm chart (`charts/karpenter-defaults`) instead of `kubernetes_manifest`. On a fresh cluster the CRDs do not exist at plan time and `kubernetes_manifest` fails the plan; Helm defers that to apply.

Set `install_helm_release = false` if Karpenter itself is delivered by Argo CD/Flux and only the IAM/SQS side should live in Terraform.

## Usage

```hcl
module "karpenter" {
  source = "git::https://github.com/lbarrosby/terraform-aws-platform.git//modules/karpenter?ref=karpenter-v1.0.0"

  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint

  node_pool = {
    capacity_types   = ["spot", "on-demand"]
    cpu_limit        = 400
    memory_limit_gib = 1600
  }

  node_class = {
    ami_alias = "al2023@v20261020" # pin in production, bump through PRs
  }
}
```

The caller configures the `helm` provider (see `examples/complete/providers.tf`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.59, < 7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0, < 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.59, < 7.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0, < 4.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | 21.29.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.defaults](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Kubernetes API endpoint, passed to the controller to skip discovery. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name (output of the eks-cluster module). | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Karpenter chart/controller version. Read the upgrade guide before bumping minors. | `string` | `"1.15.1"` | no |
| <a name="input_controller_node_selector"></a> [controller\_node\_selector](#input\_controller\_node\_selector) | Node selector for the controller. Matches the system node group label set by the eks-cluster module. | `map(string)` | ```{ "platform.io/node-role": "system" }``` | no |
| <a name="input_controller_replicas"></a> [controller\_replicas](#input\_controller\_replicas) | Controller replicas. Two gives leader election failover across system nodes. | `number` | `2` | no |
| <a name="input_create_default_node_pool"></a> [create\_default\_node\_pool](#input\_create\_default\_node\_pool) | Install the default NodePool and EC2NodeClass (local chart). Requires install\_helm\_release. | `bool` | `true` | no |
| <a name="input_helm_values"></a> [helm\_values](#input\_helm\_values) | Extra YAML values merged after the module defaults for the Karpenter chart. | `list(string)` | `[]` | no |
| <a name="input_install_helm_release"></a> [install\_helm\_release](#input\_install\_helm\_release) | Install the Karpenter chart. Set to false when the controller is deployed by GitOps and only the AWS side is wanted here. | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for the Karpenter controller. | `string` | `"kube-system"` | no |
| <a name="input_node_class"></a> [node\_class](#input\_node\_class) | Settings for the default EC2NodeClass. | ```object({ name = optional(string, "default") ami_alias = optional(string, "al2023@latest") root_volume_gib = optional(number, 50) discovery_tag_value = optional(string) })``` | `{}` | no |
| <a name="input_node_pool"></a> [node\_pool](#input\_node\_pool) | Settings for the default NodePool. | ```object({ name = optional(string, "default") capacity_types = optional(list(string), ["spot", "on-demand"]) architectures = optional(list(string), ["amd64", "arm64"]) instance_categories = optional(list(string), ["c", "m", "r"]) instance_generation = optional(number, 5) cpu_limit = optional(number, 200) memory_limit_gib = optional(number, 800) consolidation_policy = optional(string, "WhenEmptyOrUnderutilized") consolidate_after = optional(string, "1m") expire_after = optional(string, "720h") disruption_budget = optional(string, "10%") weight = optional(number, 10) })``` | `{}` | no |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Service account used by the controller (bound through Pod Identity). | `string` | `"karpenter"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources; also propagated to EC2 instances launched by the default EC2NodeClass. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_chart_version"></a> [chart\_version](#output\_chart\_version) | Installed Karpenter version, null when the chart is managed elsewhere. |
| <a name="output_controller_role_arn"></a> [controller\_role\_arn](#output\_controller\_role\_arn) | IAM role assumed by the Karpenter controller through Pod Identity. |
| <a name="output_default_node_pool_name"></a> [default\_node\_pool\_name](#output\_default\_node\_pool\_name) | Name of the default NodePool, null when not created. |
| <a name="output_interruption_queue_name"></a> [interruption\_queue\_name](#output\_interruption\_queue\_name) | SQS queue receiving spot interruption and rebalance events. |
| <a name="output_node_iam_role_arn"></a> [node\_iam\_role\_arn](#output\_node\_iam\_role\_arn) | ARN of the Karpenter node role. |
| <a name="output_node_iam_role_name"></a> [node\_iam\_role\_name](#output\_node\_iam\_role\_name) | IAM role for nodes launched by Karpenter (referenced by EC2NodeClass.spec.role). |
<!-- END_TF_DOCS -->
