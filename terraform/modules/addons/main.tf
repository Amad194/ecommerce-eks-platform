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

# ---- Default gp3 StorageClass (for stateful add-ons like Prometheus) --------
resource "kubectl_manifest" "gp3_storageclass" {
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name        = "gp3"
      annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
    }
    provisioner          = "ebs.csi.aws.com"
    parameters           = { type = "gp3", encrypted = "true" }
    volumeBindingMode    = "WaitForFirstConsumer"
    allowVolumeExpansion = true
    reclaimPolicy        = "Delete"
  })
}

# ---- Monitoring & Observability: kube-prometheus-stack ----------------------
# Prometheus + Grafana + Alertmanager. Prometheus scrapes any pod carrying the
# prometheus.io/scrape annotation (which every workload chart sets).
resource "random_password" "grafana" {
  length  = 20
  special = false
}

locals {
  grafana_host  = "grafana.${var.domain_name}"
  slack_enabled = var.alertmanager_slack_webhook_url != ""

  # Empty when Slack is disabled -> the "slack" receiver becomes a no-op.
  slack_configs = local.slack_enabled ? [{
    api_url       = var.alertmanager_slack_webhook_url
    channel       = var.alertmanager_slack_channel
    send_resolved = true
    title         = "{{ .CommonLabels.alertname }} ({{ .Status }})"
    text          = "{{ range .Alerts }}{{ .Annotations.description }}\n{{ end }}"
  }] : []

  # Literal tuple (no top-level conditional) to avoid type-unification issues.
  alertmanager_receivers = [
    { name = "null", slack_configs = [] },
    { name = "slack", slack_configs = local.slack_configs },
  ]
  alertmanager_default_receiver = local.slack_enabled ? "slack" : "null"
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.versions.kube_prometheus_stack
  namespace        = "monitoring"
  create_namespace = true

  # Base config (structured).
  values = [
    yamlencode({
      grafana = {
        adminPassword = random_password.grafana.result
        defaultDashboardsTimezone = "utc"
        persistence = {
          enabled          = true
          storageClassName = "gp3"
          size             = "10Gi"
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
            "external-dns.alpha.kubernetes.io/hostname" = local.grafana_host
            "nginx.ingress.kubernetes.io/ssl-redirect"  = "true"
          }
          hosts = [local.grafana_host]
          tls   = [{ secretName = "grafana-tls", hosts = [local.grafana_host] }]
        }
      }

      prometheus = {
        prometheusSpec = {
          retention = "15d"
          # Discover ServiceMonitors/PodMonitors/Rules from ALL namespaces.
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources        = { requests = { storage = "50Gi" } }
              }
            }
          }
        }
      }

      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources        = { requests = { storage = "5Gi" } }
              }
            }
          }
        }
        config = {
          global = { resolve_timeout = "5m" }
          route = {
            group_by        = ["alertname", "namespace"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "3h"
            receiver        = local.alertmanager_default_receiver
          }
          receivers = local.alertmanager_receivers
        }
      }
    }),

    # Annotation-based pod scraping (honours prometheus.io/{scrape,port,path}).
    # Written as literal YAML so the relabel regexes stay intact.
    <<-EOT
    prometheus:
      prometheusSpec:
        additionalScrapeConfigs:
          - job_name: kubernetes-pods
            kubernetes_sd_configs:
              - role: pod
            relabel_configs:
              - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
                action: keep
                regex: "true"
              - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
                action: replace
                target_label: __metrics_path__
                regex: (.+)
              - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
                action: replace
                regex: ([^:]+)(?::\d+)?;(\d+)
                replacement: $1:$2
                target_label: __address__
              - action: labelmap
                regex: __meta_kubernetes_pod_label_(.+)
              - source_labels: [__meta_kubernetes_namespace]
                action: replace
                target_label: namespace
              - source_labels: [__meta_kubernetes_pod_name]
                action: replace
                target_label: pod
    EOT
  ]

  depends_on = [kubectl_manifest.gp3_storageclass]
}
