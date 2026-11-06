# ECF Final — M-Motors : infrastructure "Move to Cloud" (AWS)
# Compétences C1.1 à C1.4 : création automatisée, déploiement, sécurisation et
# mise en production de l'infrastructure dans le cloud.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Production : état distant chiffré et verrouillé (S3 + DynamoDB).
  # Décommenter après création du bucket d'état.
  # backend "s3" {
  #   bucket         = "mmotors-tfstate-<account_id>"
  #   key            = "prod/terraform.tfstate"
  #   region         = "eu-west-3"
  #   encrypt        = true
  #   dynamodb_table = "mmotors-tf-lock"
  # }
}

locals {
  common_tags = {
    Project     = "m-motors"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "badr-tirari"
    CostCenter  = "location-longue-duree"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Les métriques de facturation AWS (AWS/Billing) n'existent qu'en us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}
