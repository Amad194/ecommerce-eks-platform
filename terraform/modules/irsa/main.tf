###############################################################################
# IRSA module — IAM Roles for Service Accounts for the platform add-ons.
# Uses the maintained iam-role-for-service-accounts-eks submodule, which ships
# hardened, least-privilege policies for each well-known controller.
###############################################################################

# AWS Load Balancer Controller -> provisions ALB/NLB for Ingress/Service
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                              = "${var.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  tags = var.tags
}

# Cluster Autoscaler -> scales managed node groups
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                        = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
  tags = var.tags
}

# ExternalDNS -> manages Route53 records for Ingress hosts
module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                  = "${var.cluster_name}-external-dns"
  attach_external_dns_policy = true
  external_dns_hosted_zone_arns = var.hosted_zone_arns

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
  tags = var.tags
}

# External Secrets Operator -> reads AWS Secrets Manager into k8s Secrets
module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                      = "${var.cluster_name}-external-secrets"
  attach_external_secrets_policy = true
  external_secrets_secrets_manager_arns = var.secrets_manager_arns

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
  tags = var.tags
}

# cert-manager -> DNS-01 solving via Route53
module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                  = "${var.cluster_name}-cert-manager"
  attach_cert_manager_policy = true
  cert_manager_hosted_zone_arns = var.hosted_zone_arns

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }
  tags = var.tags
}
