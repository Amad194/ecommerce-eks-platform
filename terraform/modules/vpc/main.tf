###############################################################################
# VPC module — 10.0.0.0/16 across 2 AZs.
#   public  subnets -> ALB/NLB (internet-facing)
#   private subnets -> EKS nodes + data stores
#   intra   subnets -> no NAT egress (RDS/ElastiCache/OpenSearch)
# Wraps the well-maintained terraform-aws-modules/vpc/aws module and applies the
# subnet tags EKS + the AWS Load Balancer Controller need for discovery.
###############################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  intra_subnets   = var.intra_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # VPC flow logs -> CloudWatch (security/compliance)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_max_aggregation_interval    = 60

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    # Tag for Cluster Autoscaler node-group discovery
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}
