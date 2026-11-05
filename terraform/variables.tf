variable "aws_region" {
  description = "Région AWS de déploiement"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Nom du projet, utilisé pour préfixer les ressources et leurs tags"
  type        = string
  default     = "techcorp-platform"
}

variable "environment" {
  description = "Environnement de déploiement (production / staging)"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "Type d'instance EC2. m7i-flex.large (2 vCPU / 8 Go, éligible plan gratuit AWS) recommandé : k3s + Postgres + app + Prometheus + Grafana ne tiennent pas confortablement sur un t3.micro (1 Go)."
  type        = string
  default     = "m7i-flex.large"
}

variable "allowed_ssh_cidr" {
  description = "Plage CIDR autorisée pour la connexion SSH et l'admin k3s/Grafana (ex: votre IP publique /32)"
  type        = string
}

variable "public_key_path" {
  description = "Chemin vers la clé publique SSH à injecter dans l'instance"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC dédié à l'infrastructure"
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Bloc CIDR du sous-réseau public"
  type        = string
  default     = "10.42.1.0/24"
}
