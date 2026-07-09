# Architecture — component → code mapping

Every box in the reference diagram maps to a concrete piece of this repo.

## AWS Cloud / VPC
| Diagram | Implementation |
|---|---|
| VPC 10.0.0.0/16, 2 AZs | `terraform/modules/vpc` (public / private / intra subnets, NAT, flow logs) |
| Public subnets + ALB/NLB | NLB provisioned by AWS Load Balancer Controller for `ingress-nginx` (`modules/addons`) |
| EKS Kubernetes Cluster (managed control plane) | `terraform/modules/eks` (control plane, managed node groups, OIDC/IRSA) |
| Ingress Controller (nginx-ingress) | `helm_release.ingress_nginx` in `modules/addons` |
| EKS Control Plane (managed by AWS) | EKS module — `cluster_enabled_log_types` ship logs to CloudWatch |

## Namespaces & workloads (Helm charts)
| Diagram namespace | Chart | Namespace | Ingress |
|---|---|---|---|
| frontend (React/Next.js) | `helm-charts/frontend` | `frontend` | shop.example.com |
| magento (PHP-FPM) | `helm-charts/magento` | `magento` | admin.example.com |
| api (Laravel/Node) | `helm-charts/api` | `api` | api.example.com |
| services (Go/Python/Node) | `helm-charts/microservices` | `services` | internal only |
| worker (consumers) | `helm-charts/worker` | `worker` | none (queue-driven) |
| **HPA** boxes | `common/_hpa.tpl` — HorizontalPodAutoscaler per chart (v2, CPU+mem) |

All five charts share the hardened templates in `helm-charts/common` (library chart).

## Platform Add-ons
| Diagram | Implementation (`modules/addons`) |
|---|---|
| Metrics Server | `helm_release.metrics_server` (powers HPA) |
| Cluster Autoscaler | `helm_release.cluster_autoscaler` (+ IRSA) |
| External DNS | `helm_release.external_dns` (+ IRSA, Route53) |
| Cert Manager | `helm_release.cert_manager` + `letsencrypt-prod` ClusterIssuer |
| Horizontal Pod Autoscaler | metrics-server + `common/_hpa.tpl` |
| (secrets sync) | External Secrets Operator + `ClusterSecretStore` |

## Kubernetes Core Services
| Diagram | Implementation |
|---|---|
| ConfigMaps | `common/_configmap.tpl` (per-chart `config:` block) |
| Secrets | `common/_externalsecret.tpl` → synced from AWS Secrets Manager |
| Service Accounts | `common/_serviceaccount.tpl` (IRSA-annotatable) |
| RBAC | AppProject + IRSA trust policies; least-privilege SAs |
| Network Policies | `common/_networkpolicy.tpl` (default-deny-ish per workload) |
| Pod Security Standards | namespaces labeled `pod-security…=restricted` (`environments/prod/main.tf`) |

## Data Stores
| Diagram | Module |
|---|---|
| Amazon RDS (MySQL) Multi-AZ | `terraform/modules/rds` |
| Amazon ElastiCache (Redis) | `terraform/modules/elasticache` |
| OpenSearch (Elasticsearch) | `terraform/modules/opensearch` |
| Amazon MQ (RabbitMQ) | `terraform/modules/mq` |

Each stores credentials in **AWS Secrets Manager**; workloads receive them via
External Secrets Operator → Kubernetes Secret → `envFrom`.

## Edge / Users path
| Diagram | Module |
|---|---|
| Route 53 (DNS) | `terraform/modules/route53` (+ ExternalDNS for app records) |
| CloudFront (CDN) | `terraform/modules/cloudfront` (OAC to private S3) |
| S3 (Static Assets) | `terraform/modules/s3` (`static` bucket) |
| ACM (TLS) | `terraform/modules/acm` (wildcard, DNS-validated) |

## Shared Services
| Diagram | Module |
|---|---|
| Amazon ECR | `terraform/modules/ecr` (one repo per service, scan-on-push) |
| AWS Secrets Manager | secrets created by each data-store module |
| AWS S3 (Backups) | `modules/s3` (`backups` bucket, lifecycle to Glacier) |
| CloudWatch (Logs & Metrics) | EKS control-plane logs, VPC flow logs, RDS/OpenSearch logs |
| AWS IAM (Access Control) | IRSA roles (`modules/irsa`, `modules/eks`) |
| AWS WAF (Security) | `terraform/modules/waf` (REGIONAL + CLOUDFRONT web ACLs) |

## CI/CD Pipeline
| Diagram | Implementation |
|---|---|
| Github → Pipelines → Build & Test → Docker → Push to ECR | `.github-ci.yml` |
| Deploy to EKS (Argo CD / Helm) | GitOps tag-bump commit → Argo CD auto-sync |
| (GitHub alternative) | `.github/workflows/ci.yaml` |

## Monitoring & Observability
| Diagram | Implementation (`modules/addons`) |
|---|---|
| Prometheus | `kube-prometheus-stack` — scrapes every pod via `prometheus.io/scrape` (annotation-based `additionalScrapeConfigs`) |
| Grafana | same chart — Ingress at `grafana.<domain>` (TLS via cert-manager), gp3-backed persistence; admin password is a Terraform output |
| Alertmanager | same chart — gp3-backed; Slack receiver enabled when `alertmanager_slack_webhook_url` is set |
| Notifications (Slack / Email) | Alertmanager receivers (`alertmanager_slack_channel`); add an `email_configs` receiver for SES/SendGrid |

A `gp3` StorageClass is created as the cluster default to back the stateful
monitoring components.

## Security & Compliance
| Diagram | Implementation (`modules/security`) |
|---|---|
| AWS WAF | `modules/waf` (REGIONAL + CLOUDFRONT web ACLs) |
| GuardDuty | `aws_guardduty_detector` (+ S3, EKS audit, EBS malware datasources) |
| Security Hub | `aws_securityhub_account` + AWS Foundational + CIS standards |
| Inspector | `aws_inspector2_enabler` (ECR image + EC2 host scanning) |
| CloudTrail (Audit Logs) | multi-region trail → encrypted, versioned, private S3 bucket, log-file validation |

Each control is independently toggleable (`enable_guardduty`, `enable_security_hub`,
`enable_inspector`, `enable_cloudtrail`) — all default `true`.

## Deploy ordering (dependency graph)
```
vpc → eks → irsa → addons(ingress,cert-manager,external-dns,autoscaler,ESO) → argocd → (GitOps) apps
      └─ rds / elasticache / opensearch / mq   (parallel, depend on vpc+eks SG)
route53 → acm → cloudfront ; s3 ; waf          (edge, parallel)
```
Terraform resolves this ordering automatically from resource references +
explicit `depends_on` on the `addons`/`argocd` modules.
