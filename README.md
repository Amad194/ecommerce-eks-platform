# E-Commerce Platform on Amazon EKS — Terraform + ArgoCD + Helm

A production-grade, GitOps-driven implementation of the reference architecture:
a Magento-based e-commerce platform running on Amazon EKS, with all AWS
infrastructure provisioned by **Terraform**, cluster add-ons + **Argo CD**
bootstrapped by Terraform, and every workload deployed from **centralized Helm
charts** managed by Argo CD (app-of-apps).

```
Users → Route53 → CloudFront → ALB → nginx-ingress → EKS workloads
                                                        │
                    ┌───────────────────────────────────┼───────────────────────────┐
              frontend   magento   api   services(micro)   worker
                                                        │
                    RDS(MySQL Multi-AZ) · ElastiCache(Redis) · OpenSearch · Amazon MQ(RabbitMQ)
```

## Repository layout

```
ecommerce-eks-platform/
├── terraform/
│   ├── bootstrap/            # One-time: S3 state bucket + DynamoDB lock table
│   ├── environments/prod/    # Root module — wires every infra module together
│   └── modules/              # Reusable modules
│       ├── vpc/              # VPC 10.0.0.0/16, public/private/intra subnets, NAT, 2 AZs
│       ├── eks/              # EKS control plane + managed node groups + IRSA
│       ├── rds/              # Amazon RDS MySQL, Multi-AZ
│       ├── elasticache/      # Redis replication group
│       ├── opensearch/       # OpenSearch (Elasticsearch) domain
│       ├── mq/               # Amazon MQ (RabbitMQ) broker
│       ├── ecr/              # Container registries (one per service)
│       ├── s3/               # Static assets + backups buckets
│       ├── route53/          # Public hosted zone
│       ├── acm/              # TLS certs (ALB + CloudFront)
│       ├── cloudfront/       # CDN in front of S3 static assets
│       ├── waf/              # AWS WAF web ACL
│       ├── irsa/             # IAM Roles for Service Accounts (add-ons)
│       ├── addons/           # Helm releases: ingress-nginx, cert-manager,
│       │                     #   external-dns, cluster-autoscaler, metrics-server,
│       │                     #   external-secrets, kube-prometheus-stack (monitoring)
│       ├── security/         # GuardDuty, Security Hub, Inspector, CloudTrail
│       └── argocd/           # Argo CD install + app-of-apps bootstrap
├── helm-charts/              # Centralized Helm charts (source of truth for workloads)
│   ├── common/               # Library chart — shared deployment/service/ingress/hpa templates
│   ├── frontend/             # React / Next.js          → namespace: frontend
│   ├── magento/              # Magento (PHP-FPM)         → namespace: magento
│   ├── api/                  # API service (Laravel/Node)→ namespace: api
│   ├── microservices/        # Go/Python/Node services   → namespace: services
│   └── worker/               # Async queue consumers      → namespace: worker
├── argocd/                   # GitOps manifests rendered by Argo CD
│   ├── projects/             # AppProject
│   ├── app-of-apps.yaml      # Root Application
│   └── applications/         # One Application per Helm chart
├── .github/workflows/        # CI (build/test/scan) example
└── .gitlab-ci.yml            # GitLab CI/CD pipeline (matches the reference diagram)
```

## Prerequisites

| Tool        | Version  |
|-------------|----------|
| Terraform   | >= 1.6   |
| AWS CLI     | >= 2.13  |
| kubectl     | >= 1.29  |
| Helm        | >= 3.14  |
| An AWS account with admin (bootstrap) credentials |

Configure credentials: `aws configure` (or export `AWS_PROFILE`).

## Deploy — step by step

### 0. Point at your repo & domain
This repo uses placeholder values. Edit `terraform/environments/prod/terraform.tfvars`:
- `gitops_repo_url` → the HTTPS/SSH URL of THIS repository (Argo CD reads Helm charts from it)
- `domain_name`     → your real domain (default `example.com`)

### 1. Bootstrap remote state (run once)
```bash
cd terraform/bootstrap
terraform init
terraform apply
```
Copy the output bucket/table names into `terraform/environments/prod/backend.tf`
(they already match the defaults if you kept `project=ecommerce`, `env=prod`).

### 2. Provision everything
```bash
cd ../environments/prod
terraform init
terraform apply
```
This creates the VPC, EKS, data stores, ECR, CloudFront/WAF/Route53, installs the
cluster add-ons + Argo CD, and applies the app-of-apps. Argo CD then syncs all
Helm charts automatically.

### 3. Access the cluster & Argo CD
```bash
aws eks update-kubeconfig --name ecommerce-prod-eks --region us-east-1
kubectl -n argocd get applications
# Argo CD admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo
kubectl -n argocd port-forward svc/argocd-server 8080:443
# open https://localhost:8080  (user: admin)
```

## Design notes
- **Separation of concerns:** Terraform owns *cluster + platform*; Argo CD owns *apps*.
  Add-ons that must exist before any app (ingress, cert-manager, DNS) are installed by
  Terraform so the cluster is functional the moment `apply` finishes.
- **GitOps:** Workload changes are made by editing `helm-charts/**` and merging — Argo CD
  reconciles automatically (`automated` sync + self-heal + prune).
- **DRY Helm:** `helm-charts/common` is a library chart; each app chart is a thin wrapper,
  so all 5 services share one hardened deployment/service/ingress/hpa/RBAC definition.
- **Security:** IRSA (no node-wide creds), network policies, non-root containers, pod
  security standards (restricted), secrets from AWS Secrets Manager via CSI/ESO-ready hooks.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full component mapping.
