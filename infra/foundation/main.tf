locals {
  name = "${var.team}-cloudnative-${var.environment}"
}

# Network: VPC, public + private subnets, one NAT gateway

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = var.vpc_cidr
  azs  = var.azs

  # /19 private subnets (8k IPs each): with the VPC CNI every pod takes a VPC IP.
  private_subnets = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 3, i)]
  # /24 public subnets from the upper half: only the NAT and load balancers live here.
  public_subnets = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 8, 128 + i)]

  # One NAT for all AZs.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Where EKS places internet-facing / internal load balancers.
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

# Gateway endpoints: S3 / DynamoDB traffic stays off the NAT (free, no per-GB charge)

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(["s3", "dynamodb"])

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = { Name = "${local.name}-${each.key}" }
}
