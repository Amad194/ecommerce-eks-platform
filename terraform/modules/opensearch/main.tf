###############################################################################
# OpenSearch module — managed domain for Magento catalog search (Elasticsearch
# API compatible). Deployed across 2 AZs with encryption + fine-grained access.
###############################################################################

resource "random_password" "master" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+"
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-opensearch-sg"
  description = "Allow HTTPS to OpenSearch from the EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from cluster"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_opensearch_domain" "this" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type          = var.instance_type
    instance_count         = var.instance_count
    zone_awareness_enabled = true
    zone_awareness_config {
      availability_zone_count = 2
    }
  }

  vpc_options {
    subnet_ids         = slice(var.subnet_ids, 0, 2)
    security_group_ids = [aws_security_group.this.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.volume_size
  }

  encrypt_at_rest { enabled = true }
  node_to_node_encryption { enabled = true }
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.master_username
      master_user_password = random_password.master.result
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/opensearch/${var.name_prefix}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_name = "${var.name_prefix}-opensearch-logs"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "es.amazonaws.com" }
      Action    = ["logs:PutLogEvents", "logs:CreateLogStream"]
      Resource  = "${aws_cloudwatch_log_group.this.arn}:*"
    }]
  })
}

resource "aws_secretsmanager_secret" "os" {
  name                    = "${var.name_prefix}/opensearch"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "os" {
  secret_id = aws_secretsmanager_secret.os.id
  secret_string = jsonencode({
    endpoint = aws_opensearch_domain.this.endpoint
    username = var.master_username
    password = random_password.master.result
  })
}
