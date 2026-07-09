###############################################################################
# Amazon MQ module — RabbitMQ broker for async work (order processing, email,
# indexing) consumed by the worker service.
###############################################################################

resource "random_password" "user" {
  length           = 24
  special          = true
  override_special = "-_.~" # RabbitMQ user password: limited special set
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-mq-sg"
  description = "Allow AMQPS from the EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "AMQPS from cluster"
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }
  ingress {
    description     = "RabbitMQ mgmt console"
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

resource "aws_mq_broker" "this" {
  broker_name        = "${var.name_prefix}-rabbitmq"
  engine_type        = "RabbitMQ"
  engine_version     = var.engine_version
  host_instance_type = var.instance_type
  deployment_mode    = var.deployment_mode # CLUSTER_MULTI_AZ for HA

  # Amazon MQ for RabbitMQ takes a single (private) subnet in both SINGLE_INSTANCE
  # and CLUSTER_MULTI_AZ modes — Amazon MQ handles multi-AZ placement internally.
  subnet_ids      = [var.subnet_ids[0]]
  security_groups = [aws_security_group.this.id]

  publicly_accessible = false
  auto_minor_version_upgrade = true

  user {
    username = var.username
    password = random_password.user.result
  }

  logs {
    general = true
  }

  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "06:00"
    time_zone   = "UTC"
  }

  tags = var.tags
}

resource "aws_secretsmanager_secret" "mq" {
  name                    = "${var.name_prefix}/mq/rabbitmq"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "mq" {
  secret_id = aws_secretsmanager_secret.mq.id
  secret_string = jsonencode({
    amqps_endpoint = tolist(aws_mq_broker.this.instances[0].endpoints)[0]
    console_url    = aws_mq_broker.this.instances[0].console_url
    username       = var.username
    password       = random_password.user.result
  })
}
