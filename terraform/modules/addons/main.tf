###############################################################################
# Add-ons module — the platform layer installed by Terraform so the cluster is
# immediately functional. All are Helm releases; IAM comes from IRSA roles.
#
#   metrics-server            -> powers HPA (the "HPA" boxes in the diagram)
#   cluster-autoscaler        -> scales node groups
#   aws-load-balancer-ctrl    -> provisions ALB/NLB for ingress-nginx
#   ingress-nginx             -> the nginx Ingress Controller (edge of cluster)
#   cert-manager (+issuer)    -> TLS certificates
#   external-dns              -> Route53 records for Ingress hosts
###############################################################################

# ---- metrics-server ---------------------------------------------------------
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.versions.metrics_server
  namespace        = "kube-system"
  create_namespace = false

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

# ---- AWS Load Balancer Controller ------------------------------------------
resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.versions.lb_controller
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.lb_controller_role_arn
  }
}

# ---- Cluster Autoscaler -----------------------------------------------------
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.versions.cluster_autoscaler
  namespace  = "kube-system"

  set {
    name  = "cloudProvider"
    value = "aws"
  }
  set {
    name  = "awsRegion"
    value = var.region
  }
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cluster_autoscaler_role_arn
  }
  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }
}

# ---- ingress-nginx ----------------------------------------------------------
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.versions.ingress_nginx
  namespace        = "ingress-nginx"
  create_namespace = true

  # Front the nginx controller with an internet-facing NLB provisioned by the
  # AWS Load Balancer Controller, terminating TLS via the ACM cert.
  values = [yamlencode({
    controller = {
      replicaCount = 2
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "ip"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"                          = var.acm_certificate_arn
          "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"                         = "https"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        }
      }
      metrics = { enabled = true }
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = "10254"
      }
    }
  })]

  depends_on = [helm_release.lb_controller]
}

# ---- cert-manager -----------------------------------------------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.versions.cert_manager
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "crds.enabled"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "cert-manager"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cert_manager_role_arn
  }
}

# Let's Encrypt ClusterIssuer using Route53 DNS-01 (cert-manager IRSA role).
resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt-prod" }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = { name = "letsencrypt-prod" }
        solvers = [{
          dns01 = {
            route53 = { region = var.region }
          }
        }]
      }
    }
  })
  depends_on = [helm_release.cert_manager]
}

# ---- External Secrets Operator ---------------------------------------------
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.versions.external_secrets
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_secrets_role_arn
  }
}

# ClusterSecretStore pointing at AWS Secrets Manager (auth via ESO's IRSA SA).
resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata   = { name = "aws-secrets-manager" }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  })
  depends_on = [helm_release.external_secrets]
}

# ---- ExternalDNS ------------------------------------------------------------
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.versions.external_dns
  namespace  = "kube-system"

  values = [yamlencode({
    provider = "aws"
    aws      = { region = var.region }
    domainFilters = [var.domain_name]
    policy        = "upsert-only"
    txtOwnerId    = var.cluster_name
    serviceAccount = {
      create = true
      name   = "external-dns"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.external_dns_role_arn
      }
    }
  })]
}
