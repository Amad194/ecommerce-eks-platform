###############################################################################
# Argo CD module — installs Argo CD via Helm and bootstraps GitOps.
# After apply, Argo CD owns every workload: it watches the `argocd/applications`
# path of this repo (app-of-apps) and syncs the Helm charts under helm-charts/.
###############################################################################

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [yamlencode({
    global = { domain = "argocd.${var.domain_name}" }

    configs = {
      params = {
        # TLS is terminated at the NLB/ingress; run the API server insecure internally.
        "server.insecure" = true
      }
      cm = {
        "timeout.reconciliation" = "180s"
        "kustomize.buildOptions" = "--enable-helm"
      }
    }

    server = {
      replicas = 2
      ingress = {
        enabled          = var.expose_ingress
        ingressClassName = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer"                 = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
          "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
          "external-dns.alpha.kubernetes.io/hostname"      = "argocd.${var.domain_name}"
        }
        hostname = "argocd.${var.domain_name}"
        tls      = true
      }
    }

    controller = { replicas = 1 }
    repoServer = { replicas = 2 }
    applicationSet = { replicas = 1 }
    dex = { enabled = false }
  })]
}

###############################################################################
# GitOps bootstrap — the AppProject + the root "app-of-apps".
###############################################################################

resource "kubectl_manifest" "project" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "ecommerce"
      namespace = var.namespace
    }
    spec = {
      description  = "E-commerce platform workloads"
      sourceRepos  = [var.gitops_repo_url]
      destinations = [{ server = "https://kubernetes.default.svc", namespace = "*" }]
      clusterResourceWhitelist = [{ group = "*", kind = "*" }]
      namespaceResourceWhitelist = [{ group = "*", kind = "*" }]
    }
  })
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "root_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "app-of-apps"
      namespace  = var.namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "ecommerce"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.target_revision
        path           = "argocd/applications"
        directory      = { recurse = true }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })
  depends_on = [kubectl_manifest.project]
}
