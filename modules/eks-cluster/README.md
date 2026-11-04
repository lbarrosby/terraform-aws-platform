# eks-cluster

Opinionated wrapper around [`terraform-aws-modules/eks`](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws) `21.29.0`.
It exposes a small, validated interface and bakes in the defaults a platform team ends up enforcing anyway.

## What you get

- **Access entries only** (`authentication_mode = "API"`). No `aws-auth` ConfigMap. Admins are passed as IAM ARNs in `admin_principal_arns`.
- **EKS Pod Identity** as the workload identity mechanism. IRSA/OIDC is off unless `enable_irsa = true`.
- **System managed node group** (`system`) with the `CriticalAddonsOnly=true:NoSchedule` taint and the `platform.io/node-role=system` label. It hosts CoreDNS, Karpenter and CSI controllers; application capacity comes from Karpenter.
- **Core managed add-ons**: `vpc-cni` (prefix delegation on), `eks-pod-identity-agent`, `kube-proxy`, `coredns`, `aws-ebs-csi-driver` (Pod Identity role created here). Versions are resolved by `aws_eks_addon_version` for the cluster version and can be pinned per add-on.
- **Secrets envelope encryption** with a dedicated KMS key (rotation on) or a key you bring.
- **Control plane logs** for all five log types with explicit retention.
- **Private API endpoint** by default. A public endpoint requires an explicit CIDR allow list; `0.0.0.0/0` is rejected.
- `upgrade_policy.support_type = STANDARD` by default, so nobody pays for extended support by accident.
- IMDSv2 only with hop limit 1, gp3 encrypted root volumes, SSM access, node auto repair.

## Usage

```hcl
module "eks" {
  source = "git::https://github.com/lbarrosby/terraform-aws-platform.git//modules/eks-cluster?ref=eks-cluster-v1.0.0"

  name               = "plat-prod-use1"
  kubernetes_version = "1.34"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.intra_subnet_ids

  admin_principal_arns = [
    "arn:aws:iam::111111111111:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_PlatformAdmin_0123456789abcdef",
    "arn:aws:iam::111111111111:role/ci-terraform",
  ]

  addon_overrides = {
    coredns = { configuration_values = jsonencode({ replicaCount = 3 }) }
  }

  tags = { "platform:environment" = "prod" }
}
```

## Upgrading Kubernetes

1. Bump `kubernetes_version` by one minor. Control plane goes first, then the system node group rolls (33% at a time).
2. Add-on versions follow automatically through the data source unless pinned in `addon_overrides`.
3. Karpenter nodes drift to the new AMI on their own (`al2023@latest`) or when you bump the pinned alias.

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

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.29.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_eks_addon_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_iam_policy_document.pod_identity_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes minor version (e.g. "1.34"). Upgrades are one minor at a time; bump it explicitly. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Cluster name. Also used as prefix for IAM roles, KMS alias and the Karpenter discovery tag. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private subnets for the system node group (and for the control plane ENIs when control\_plane\_subnet\_ids is empty). Use at least two AZs. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC where the cluster and nodes live. | `string` | n/a | yes |
| <a name="input_access_entries"></a> [access\_entries](#input\_access\_entries) | Additional access entries, passed through to the upstream module (same schema). | ```map(object({ kubernetes_groups = optional(list(string)) principal_arn = string type = optional(string, "STANDARD") user_name = optional(string) tags = optional(map(string), {}) policy_associations = optional(map(object({ policy_arn = string access_scope = object({ namespaces = optional(list(string)) type = string }) })), {}) }))``` | `{}` | no |
| <a name="input_addon_overrides"></a> [addon\_overrides](#input\_addon\_overrides) | Per add-on overrides for the managed core add-ons. Pin `version` to freeze an add-on; `configuration_values` is a JSON string. | ```map(object({ version = optional(string) configuration_values = optional(string) }))``` | `{}` | no |
| <a name="input_addons_most_recent"></a> [addons\_most\_recent](#input\_addons\_most\_recent) | Resolve add-on versions to the most recent build for the Kubernetes version instead of the EKS default build. | `bool` | `false` | no |
| <a name="input_admin_principal_arns"></a> [admin\_principal\_arns](#input\_admin\_principal\_arns) | IAM role/user ARNs granted AmazonEKSClusterAdminPolicy through access entries (typically the platform team SSO role and the CI role). | `list(string)` | `[]` | no |
| <a name="input_control_plane_subnet_ids"></a> [control\_plane\_subnet\_ids](#input\_control\_plane\_subnet\_ids) | Dedicated subnets for the control plane cross-account ENIs (e.g. small intra subnets). Defaults to subnet\_ids. | `list(string)` | `[]` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable EKS deletion protection on the cluster. | `bool` | `true` | no |
| <a name="input_enable_cluster_creator_admin_permissions"></a> [enable\_cluster\_creator\_admin\_permissions](#input\_enable\_cluster\_creator\_admin\_permissions) | Grant cluster admin to the identity running Terraform. Prefer admin\_principal\_arns; this exists for bootstrap. | `bool` | `false` | no |
| <a name="input_enable_ebs_csi_driver"></a> [enable\_ebs\_csi\_driver](#input\_enable\_ebs\_csi\_driver) | Install aws-ebs-csi-driver with a Pod Identity role. | `bool` | `true` | no |
| <a name="input_enable_irsa"></a> [enable\_irsa](#input\_enable\_irsa) | Create the IAM OIDC provider for IRSA. Off by default: workloads use EKS Pod Identity. | `bool` | `false` | no |
| <a name="input_enabled_log_types"></a> [enabled\_log\_types](#input\_enabled\_log\_types) | Control plane log types shipped to CloudWatch. | `list(string)` | ```[ "api", "audit", "authenticator", "controllerManager", "scheduler" ]``` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Expose the Kubernetes API publicly. Private access is always on. | `bool` | `false` | no |
| <a name="input_endpoint_public_access_cidrs"></a> [endpoint\_public\_access\_cidrs](#input\_endpoint\_public\_access\_cidrs) | CIDRs allowed to reach the public API endpoint. Required (and must not be 0.0.0.0/0) when endpoint\_public\_access is true. | `list(string)` | `[]` | no |
| <a name="input_karpenter_discovery"></a> [karpenter\_discovery](#input\_karpenter\_discovery) | Tag the node security group with karpenter.sh/discovery=<name> so EC2NodeClass can select it. | `bool` | `true` | no |
| <a name="input_kms_key_administrators"></a> [kms\_key\_administrators](#input\_kms\_key\_administrators) | IAM principals allowed to administer the module-managed KMS key. Defaults to the caller identity. | `list(string)` | `[]` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Existing KMS key for envelope encryption of Kubernetes secrets. When null a dedicated key with rotation is created. | `string` | `null` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Retention for the control plane log group. | `number` | `90` | no |
| <a name="input_support_type"></a> [support\_type](#input\_support\_type) | EKS upgrade policy. STANDARD fails loudly at end of standard support instead of silently billing EXTENDED support. | `string` | `"STANDARD"` | no |
| <a name="input_system_node_group"></a> [system\_node\_group](#input\_system\_node\_group) | Managed node group dedicated to cluster-critical pods (CoreDNS, Karpenter, CSI controllers). Tainted with CriticalAddonsOnly so application pods land on Karpenter capacity. | ```object({ instance_types = optional(list(string), ["m7i.large", "m6i.large"]) ami_type = optional(string, "AL2023_x86_64_STANDARD") capacity_type = optional(string, "ON_DEMAND") min_size = optional(number, 2) max_size = optional(number, 4) desired_size = optional(number, 2) disk_size_gib = optional(number, 50) labels = optional(map(string), {}) taint = optional(bool, true) })``` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. Merged on top of the module default tags. | `map(string)` | `{}` | no |
| <a name="input_vpc_cni_prefix_delegation"></a> [vpc\_cni\_prefix\_delegation](#input\_vpc\_cni\_prefix\_delegation) | Enable prefix delegation on the VPC CNI (higher pod density, fewer ENI calls). | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addon_versions"></a> [addon\_versions](#output\_addon\_versions) | Resolved version per managed add-on. |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Control plane log group. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | EKS cluster ARN. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded cluster CA, for kubeconfig and the helm/kubernetes providers. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API endpoint. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name. |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | EKS-managed primary security group. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Additional cluster security group created by the module. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version running on the control plane. |
| <a name="output_ebs_csi_role_arn"></a> [ebs\_csi\_role\_arn](#output\_ebs\_csi\_role\_arn) | Pod Identity role used by the EBS CSI controller. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | KMS key used for secrets envelope encryption. |
| <a name="output_kubeconfig_command"></a> [kubeconfig\_command](#output\_kubeconfig\_command) | Convenience command to update the local kubeconfig. |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | Shared node security group (tagged for Karpenter discovery). |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | IAM OIDC provider ARN. Null unless enable\_irsa is true. |
| <a name="output_system_node_group_iam_role_arn"></a> [system\_node\_group\_iam\_role\_arn](#output\_system\_node\_group\_iam\_role\_arn) | IAM role of the system managed node group. |
<!-- END_TF_DOCS -->
