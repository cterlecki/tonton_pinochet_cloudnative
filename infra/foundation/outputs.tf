output "vpc_id" {
  description = "VPC id."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets, for the EKS nodes."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnets, for internet-facing load balancers."
  value       = module.vpc.public_subnets
}
