###############################################################################
# Edit these before `terraform apply`.
###############################################################################

project     = "ecommerce"
environment = "prod"
region      = "us-east-1"
azs         = ["us-east-1a", "us-east-1b"]

# --- Domain / TLS --- swap the placeholder for your real domain -------------
domain_name        = "example.com"
create_hosted_zone = true
acme_email         = "platform@example.com"

# --- GitOps --- set to THIS repository's clone URL --------------------------
gitops_repo_url        = "https://github.com/Amad194/ecommerce-eks-platform.git"
gitops_target_revision = "HEAD"

# --- Monitoring & alerting --------------------------------------------------
# Paste a Slack incoming-webhook URL to route Alertmanager alerts to Slack.
# Leave empty to disable Slack routing. (Prefer a *.tfvars.local or TF_VAR_ env
# var so the secret never lands in git.)
# alertmanager_slack_webhook_url = "https://hooks.slack.com/services/XXX/YYY/ZZZ"
alertmanager_slack_channel = "#alerts"

# --- Security & compliance (all default to true) ----------------------------
enable_guardduty    = true
enable_security_hub = true
enable_inspector    = true
enable_cloudtrail   = true

# --- Cost knobs -------------------------------------------------------------
# For a cheaper dev/demo run, downsize:
#   single_nat_gateway       = true
#   node_instance_types      = ["t3.large"]
#   rds_instance_class       = "db.t4g.medium"
#   redis_node_type          = "cache.t4g.small"
#   opensearch_instance_type = "t3.medium.search"
#   mq_instance_type         = "mq.t3.micro"
#   mq_deployment_mode       = "SINGLE_INSTANCE"
single_nat_gateway = false
