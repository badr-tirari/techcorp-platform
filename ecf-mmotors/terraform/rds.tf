# Question 2c — DaaS PostgreSQL (Amazon RDS)
#
# Réponse aux exigences RPO / RTO :
#  - RPO 24 h : sauvegardes automatiques quotidiennes + journaux de transactions
#    (restauration à la minute près, PITR ~5 min) => RPO réel << 24 h.
#  - RTO 3 h : restauration d'un snapshot / PITR dans une nouvelle instance en
#    20 à 40 min ; option multi_az (standby synchrone, bascule < 2 min).

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.private_data[*].id
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${local.name}-pg16"
  family = "postgres16"

  # Connexions chiffrées TLS obligatoires
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Journalise les requêtes lentes (> 1 s) pour la supervision applicative
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100 # extension automatique du stockage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "mmotors"
  username = "mmotors_admin"
  # Mot de passe généré et stocké par AWS Secrets Manager (rotation possible)
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period  = var.db_backup_retention_days
  backup_window            = "01:00-02:00"
  maintenance_window       = "sun:03:00-sun:04:00"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = !var.db_deletion_protection
  final_snapshot_identifier = var.db_deletion_protection ? "${local.name}-postgres-final" : null

  tags = { Name = "${local.name}-postgres", Backup = "daily" }
}
