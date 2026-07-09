###############################################################################
# ElastiCache module — Redis replication group (Multi-AZ, TLS, auth token).
# Used by Magento for session + page cache.
###############################################################################

resource "random_password" "auth" {
  length  = 32
  special = false # Redis AUTH tokens disallow most specials
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Allow Redis from the EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from cluster"
    from_port       = 6379
    to_port         = 6379
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

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "Redis for ${var.name_prefix}"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]
  parameter_group_name = "default.redis7.cluster.on"

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.auth.result

  snapshot_retention_limit = 7
  snapshot_window          = "02:00-03:00"
  maintenance_window       = "sun:05:00-sun:06:00"

  tags = var.tags
}

resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.name_prefix}/elasticache/redis"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    host       = aws_elasticache_replication_group.this.configuration_endpoint_address
    port       = 6379
    auth_token = random_password.auth.result
    tls        = true
  })
}
