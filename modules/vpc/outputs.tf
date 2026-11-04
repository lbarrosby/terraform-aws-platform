output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR."
  value       = module.vpc.vpc_cidr_block
}

output "azs" {
  description = "AZs used by the subnets, in order."
  value       = local.azs
}

output "private_subnet_ids" {
  description = "Private subnets (nodes and pods)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnets (internet-facing load balancers, NAT)."
  value       = module.vpc.public_subnets
}

output "intra_subnet_ids" {
  description = "Isolated subnets for the EKS control plane ENIs."
  value       = module.vpc.intra_subnets
}

output "private_subnet_cidrs" {
  description = "CIDRs of the private subnets."
  value       = local.private_subnets
}

output "private_route_table_ids" {
  description = "Private route table IDs."
  value       = module.vpc.private_route_table_ids
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways (useful for partner allow lists)."
  value       = module.vpc.nat_public_ips
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs keyed by service."
  value       = { for k, v in module.endpoints.endpoints : k => v.id }
}
