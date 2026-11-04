# vpc

Wrapper around [`terraform-aws-modules/vpc`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) `6.7.3` with a fixed subnet layout for EKS.

| Tier | Size (for a /16) | Purpose | Tags |
|------|------------------|---------|------|
| private | /19 per AZ | nodes and pods (prefix delegation eats IPs) | `kubernetes.io/role/internal-elb`, `karpenter.sh/discovery` |
| public | /24 per AZ | internet-facing load balancers, NAT | `kubernetes.io/role/elb` |
| intra | /24 per AZ | EKS control plane ENIs, no internet route | - |

- `nat_gateway_mode`: `one_per_az` (default, production), `single` (non-prod) or `none`.
- Flow logs to CloudWatch with 60s aggregation and explicit retention.
- Default security group, NACL and route table are adopted and left empty.
- Optional VPC endpoints: `s3` as gateway endpoint (free, attached to private and intra route tables) and interface endpoints (`ecr.api`, `ecr.dkr`, `sts`, `ec2`, ...) with a dedicated SG allowing HTTPS from the VPC. Interface endpoints cost money per AZ, so the list is empty by default.

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/lbarrosby/terraform-aws-platform.git//modules/vpc?ref=vpc-v1.0.0"

  name     = "plat-prod-use1"
  cidr     = "10.40.0.0/16"
  az_count = 3

  nat_gateway_mode        = "one_per_az"
  eks_cluster_names       = ["plat-prod-use1"]
  karpenter_discovery_tag = "plat-prod-use1"

  vpc_endpoints = ["s3", "ecr.api", "ecr.dkr", "sts", "ec2"]
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

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_endpoints"></a> [endpoints](#module\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | 6.7.3 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 6.7.3 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | VPC IPv4 CIDR. /16 to /20; subnets are carved automatically. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | VPC name, also used as prefix for subnets, route tables and endpoints. | `string` | n/a | yes |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of AZs to spread subnets over. Ignored when azs is set. | `number` | `3` | no |
| <a name="input_azs"></a> [azs](#input\_azs) | Explicit AZ names. Prefer zone IDs consistency across accounts when sharing subnets. | `list(string)` | `[]` | no |
| <a name="input_eks_cluster_names"></a> [eks\_cluster\_names](#input\_eks\_cluster\_names) | Clusters that will use this VPC. Adds kubernetes.io/cluster/<name>=shared to private and public subnets. | `list(string)` | `[]` | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Ship VPC flow logs to CloudWatch Logs. | `bool` | `true` | no |
| <a name="input_flow_logs_retention_in_days"></a> [flow\_logs\_retention\_in\_days](#input\_flow\_logs\_retention\_in\_days) | Retention for the flow log group. | `number` | `30` | no |
| <a name="input_karpenter_discovery_tag"></a> [karpenter\_discovery\_tag](#input\_karpenter\_discovery\_tag) | Value for the karpenter.sh/discovery tag on private subnets (usually the cluster name). Null disables the tag. | `string` | `null` | no |
| <a name="input_nat_gateway_mode"></a> [nat\_gateway\_mode](#input\_nat\_gateway\_mode) | "one\_per\_az" (HA, production), "single" (cheaper, non-prod) or "none". | `string` | `"one_per_az"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_vpc_endpoints"></a> [vpc\_endpoints](#input\_vpc\_endpoints) | VPC endpoints to create. s3 is a gateway endpoint (free); the rest are interface endpoints billed per AZ-hour. Empty list disables. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_azs"></a> [azs](#output\_azs) | AZs used by the subnets, in order. |
| <a name="output_intra_subnet_ids"></a> [intra\_subnet\_ids](#output\_intra\_subnet\_ids) | Isolated subnets for the EKS control plane ENIs. |
| <a name="output_nat_public_ips"></a> [nat\_public\_ips](#output\_nat\_public\_ips) | Elastic IPs of the NAT gateways (useful for partner allow lists). |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | Private route table IDs. |
| <a name="output_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#output\_private\_subnet\_cidrs) | CIDRs of the private subnets. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnets (nodes and pods). |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnets (internet-facing load balancers, NAT). |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | VPC CIDR. |
| <a name="output_vpc_endpoint_ids"></a> [vpc\_endpoint\_ids](#output\_vpc\_endpoint\_ids) | VPC endpoint IDs keyed by service. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID. |
<!-- END_TF_DOCS -->
