# App-repo CI templates

This directory holds the pipeline that belongs in each **application** repo —
**not** in this repo. This repo is the infra + GitOps config repo; it only
*validates* (see `.github/workflows/ci.yaml`) and is the *target* of image-tag
bumps. It never builds container images.

## `github-actions-app.yml`
Copy into an application repo (one of: `frontend`, `magento`, `api`,
`microservices`, `worker`) as `.github/workflows/deploy.yml`, then set the
`SERVICE` env to that repo's service name.

### What it does (on push to `main`)
1. **test** → **build** the Docker image → **Trivy** scan (fails on HIGH/CRITICAL)
2. **push** to `ECR:/ecommerce-prod/<service>:<git-sha>`
3. open a **PR against this config repo** bumping `helm-charts/<service>/values.yaml`
   → `image.tag`
4. You review + merge the PR → **Argo CD** auto-syncs and deploys

```
app repo  ──build/scan/push ECR──►  ECR
   │
   └──opens PR (image.tag bump)──►  config repo (this one)  ──Argo CD──►  EKS
```

### Required secrets in the app repo
| Secret | Purpose |
|---|---|
| `AWS_CI_ROLE_ARN` | IAM role (OIDC) permitted to push to ECR |
| `CONFIG_REPO_TOKEN` | GitHub PAT / App token with `repo` write on `Amad194/ecommerce-eks-platform` |

### Why PR-based (not direct commit)
Every production deploy goes through a reviewable PR with an audit trail, and
merge = deploy. Switch to auto-merge (or Argo CD Image Updater) later if you
want fully hands-off promotion.
