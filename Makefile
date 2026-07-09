SHELL := /bin/bash
REGION ?= us-east-1
TF_PROD := terraform/environments/prod
CHARTS  := frontend magento api microservices worker

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

## --- Terraform ---
.PHONY: bootstrap
bootstrap: ## Create the remote-state bucket + lock table (run once)
	terraform -chdir=terraform/bootstrap init
	terraform -chdir=terraform/bootstrap apply

.PHONY: init
init: ## terraform init (prod)
	terraform -chdir=$(TF_PROD) init

.PHONY: plan
plan: ## terraform plan (prod)
	terraform -chdir=$(TF_PROD) plan

.PHONY: apply
apply: ## terraform apply (prod)
	terraform -chdir=$(TF_PROD) apply

.PHONY: destroy
destroy: ## terraform destroy (prod)
	terraform -chdir=$(TF_PROD) destroy

.PHONY: fmt
fmt: ## terraform fmt (recursive)
	terraform fmt -recursive terraform

.PHONY: validate
validate: ## terraform validate (prod)
	terraform -chdir=$(TF_PROD) validate

## --- Kubernetes / Argo CD ---
.PHONY: kubeconfig
kubeconfig: ## Point kubectl at the cluster
	aws eks update-kubeconfig --name ecommerce-prod-eks --region $(REGION)

.PHONY: argocd-password
argocd-password: ## Print the initial Argo CD admin password
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d ; echo

.PHONY: argocd-ui
argocd-ui: ## Port-forward the Argo CD UI to https://localhost:8080
	kubectl -n argocd port-forward svc/argocd-server 8080:443

## --- Helm ---
.PHONY: helm-deps
helm-deps: ## Build library-chart dependencies for every app chart
	@for c in $(CHARTS); do helm dependency build helm-charts/$$c; done

.PHONY: helm-lint
helm-lint: helm-deps ## Lint + render every app chart
	@for c in $(CHARTS); do helm lint helm-charts/$$c && helm template helm-charts/$$c >/dev/null; done
