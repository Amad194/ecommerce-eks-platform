###############################################################################
# RDS module — Amazon RDS for MySQL, Multi-AZ.
# Credentials are generated and stored in AWS Secrets Manager (never in state
# as plaintext output). The DB lives in the intra (no-NAT) subnets.
###############################################################################

resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-mysql"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-mysql-sg"
  description = "Allow MySQL from the EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from cluster"
    from_port       = 3306
    to_port         = 3306
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

resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "max_connections"
    value = "1000"
  }
  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result
  port     = 3306

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period    = var.backup_retention_period
  backup_window              = "03:00-04:00"
  maintenance_window         = "sun:04:30-sun:05:30"
  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = !var.deletion_protection
  final_snapshot_identifier  = var.deletion_protection ? "${var.name_prefix}-mysql-final" : null

  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = var.tags
}

###############################################################################
# Store the connection details in Secrets Manager for apps to consume via IRSA.
###############################################################################
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name_prefix}/rds/mysql"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    username = var.master_username
    password = random_password.master.result
  })
}
