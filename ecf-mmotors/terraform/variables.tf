variable "aws_region" {
  description = "Région AWS principale (Paris, données clients en France)"
  type        = string
  default     = "eu-west-3"
}

variable "project" {
  description = "Préfixe des ressources"
  type        = string
  default     = "mmotors"
}

variable "environment" {
  description = "Environnement (prod, staging...)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "Plage d'adresses du VPC"
  type        = string
  default     = "10.50.0.0/16"
}

variable "alert_email" {
  description = "Adresse qui reçoit les alertes CloudWatch et budget"
  type        = string
}

variable "github_repo" {
  description = "Dépôt GitHub autorisé à déployer via OIDC (owner/repo)"
  type        = string
  default     = "badr-tirari/techcorp-platform"
}

variable "create_github_oidc_provider" {
  description = "false si le fournisseur OIDC GitHub existe déjà dans le compte"
  type        = bool
  default     = true
}

# --- Back-end ECS ---------------------------------------------------------
variable "container_port" {
  type    = number
  default = 8000
}

variable "image_tag" {
  description = "Tag d'image du premier déploiement (ensuite piloté par la CI/CD)"
  type        = string
  default     = "latest"
}

variable "app_desired_count" {
  description = "Nombre de tâches Fargate (2 = une par zone de disponibilité)"
  type        = number
  default     = 2
}

variable "app_max_count" {
  type    = number
  default = 4
}

# --- Base de données (DaaS PostgreSQL) -----------------------------------
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Standby synchrone dans une 2e AZ (bascule < 2 min). false suffit pour un RTO de 3 h."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Rétention des sauvegardes automatiques (RPO 24 h exigé ; PITR à 5 min obtenu)"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

# --- Environnement de dev -----------------------------------------------
variable "dev_instance_type" {
  type    = string
  default = "t3.small"
}

variable "schedule_timezone" {
  type    = string
  default = "Europe/Paris"
}

# --- FinOps ---------------------------------------------------------------
variable "monthly_budget_usd" {
  description = "Budget mensuel AWS du projet (alerte à 80 % réel et 100 % prévisionnel)"
  type        = number
  default     = 150
}

variable "billing_alarm_threshold_usd" {
  description = "Seuil de l'alarme CloudWatch sur les frais estimés du mois"
  type        = number
  default     = 100
}
