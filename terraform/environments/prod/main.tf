###############################################################################
# prod root module — composes the whole platform.
#
#   VPC ─► EKS ─► IRSA ─► add-ons ─► Argo CD (GitOps)
#    │
#    ├─ RDS (MySQL Multi-AZ) · ElastiCache (Redis) · OpenSearch · Amazon MQ
#    └─ Route53 ─► ACM ─► WAF ─► CloudFront ─► S3 (static assets + backups)
###############################################################################

locals {
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = "${var.project}-${var.environment}-eks"
  services     = ["frontend", "magento", "api", "microservices", "worker"]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ---- Networking -------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name_prefix        = local.name_prefix
  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  intra_subnets      = var.intra_subnets
  single_nat_gateway = var.single_nat_gateway
  tags               = local.tags
}

# ---- EKS --------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  intra_subnet_ids   = module.vpc.intra_subnet_ids

  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size

  tags = local.tags
}

# ---- DNS / TLS --------------------------------------------------------------
module "route53" {
  source = "../../modules/route53"

  domain_name = var.domain_name
  create_zone = var.create_hosted_zone
  tags        = local.tags
}

# CDN alias (cdn.<domain> -> CloudFront). Defined here, not in the route53
# module, to break the route53 -> acm -> cloudfront -> route53 cycle.
resource "aws_route53_record" "cdn" {
  zone_id = module.route53.zone_id
  name    = "cdn.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.cloudfront.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront's fixed hosted zone ID
    evaluate_target_health = false
  }
}

module "acm" {
  source = "../../modules/acm"

  domain_name = var.domain_name
  zone_id     = module.route53.zone_id
  tags        = local.tags
}

# ---- IRSA (needs the OIDC provider + hosted zone) ---------------------------
module "irsa" {
  source = "../../modules/irsa"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  hosted_zone_arns  = [module.route53.zone_arn]
  tags              = local.tags
}

# ---- Data stores ------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.intra_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  instance_class             = var.rds_instance_class
  tags                       = local.tags
}

module "elasticache" {
  source = "../../modules/elasticache"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.intra_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  node_type                  = var.redis_node_type
  tags                       = local.tags
}

module "opensearch" {
  source = "../../modules/opensearch"

  name_prefix                = local.name_prefix
  domain_name                = "${var.project}-${var.environment}-os"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.intra_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  instance_type              = var.opensearch_instance_type
  tags                       = local.tags
}

module "mq" {
  source = "../../modules/mq"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.intra_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  instance_type              = var.mq_instance_type
  deployment_mode            = var.mq_deployment_mode
  tags                       = local.tags
}

# ---- Registry ---------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  name_prefix  = local.name_prefix
  repositories = local.services
  tags         = local.tags
}

# ---- Static assets + edge ---------------------------------------------------
module "s3" {
  source = "../../modules/s3"

  name_prefix = local.name_prefix
  tags        = local.tags
}

module "waf_regional" {
  source = "../../modules/waf"

  name_prefix = local.name_prefix
  scope       = "REGIONAL"
  tags        = local.tags
}

module "waf_cloudfront" {
  source    = "../../modules/waf"
  providers = { aws = aws.us_east_1 }

  name_prefix = local.name_prefix
  scope       = "CLOUDFRONT"
  tags        = local.tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  name_prefix                    = local.name_prefix
  s3_bucket_regional_domain_name = module.s3.static_bucket_regional_domain_name
  acm_certificate_arn            = module.acm.certificate_arn
  web_acl_arn                    = module.waf_cloudfront.web_acl_arn
  aliases                        = ["cdn.${var.domain_name}"]
  tags                           = local.tags
}

# Break the S3 <-> CloudFront module cycle: attach the OAC read policy here,
# once both the bucket and the distribution exist.
data "aws_iam_policy_document" "static_cf" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${module.s3.static_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "static_cf" {
  bucket = module.s3.static_bucket_id
  policy = data.aws_iam_policy_document.static_cf.json
}

# ---- Platform add-ons (Helm) ------------------------------------------------
module "addons" {
  source = "../../modules/addons"

  cluster_name        = local.cluster_name
  region              = var.region
  vpc_id              = module.vpc.vpc_id
  domain_name         = var.domain_name
  acme_email          = var.acme_email
  acm_certificate_arn = module.acm.certificate_arn

  lb_controller_role_arn      = module.irsa.lb_controller_role_arn
  cluster_autoscaler_role_arn = module.irsa.cluster_autoscaler_role_arn
  external_dns_role_arn       = module.irsa.external_dns_role_arn
  cert_manager_role_arn       = module.irsa.cert_manager_role_arn
  external_secrets_role_arn   = module.irsa.external_secrets_role_arn

  depends_on = [module.eks]
}

# ---- Application namespaces (Pod Security Standards: restricted) ------------
# Pre-created with PSS labels so Argo CD (CreateNamespace=true) adopts them.
locals {
  app_namespaces = ["frontend", "magento", "api", "services", "worker"]
}

resource "kubernetes_namespace" "apps" {
  for_each = toset(local.app_namespaces)

  metadata {
    name = each.value
    labels = {
      "pod-security.kubernetes.io/enforce"         = "restricted"
      "pod-security.kubernetes.io/enforce-version" = "latest"
      "pod-security.kubernetes.io/audit"           = "restricted"
      "pod-security.kubernetes.io/warn"            = "restricted"
      "app.kubernetes.io/part-of"                  = "ecommerce-platform"
    }
  }

  depends_on = [module.eks]
}

# ---- Argo CD (GitOps) -------------------------------------------------------
module "argocd" {
  source = "../../modules/argocd"

  domain_name     = var.domain_name
  gitops_repo_url = var.gitops_repo_url
  target_revision = var.gitops_target_revision

  depends_on = [module.addons]
}
