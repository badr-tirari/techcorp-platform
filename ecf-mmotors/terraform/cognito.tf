# "Le login user est basé sur AWS Cognito"
# Un annuaire unique, deux groupes : clients (espace client) et back-office.

resource "aws_cognito_user_pool" "clients" {
  name                     = "${local.name}-users"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration        = "OPTIONAL"
  deletion_protection      = "INACTIVE"

  software_token_mfa_configuration {
    enabled = true
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 3
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false # les clients s'inscrivent eux-mêmes
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 254
    }
  }
}

resource "aws_cognito_user_group" "clients" {
  name         = "clients"
  user_pool_id = aws_cognito_user_pool.clients.id
  description  = "Clients : depot et suivi de dossiers achat/location"
}

resource "aws_cognito_user_group" "backoffice" {
  name         = "backoffice"
  user_pool_id = aws_cognito_user_pool.clients.id
  description  = "Personnel M-Motors : vehicules et validation des dossiers"
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.name}-${local.account_id}"
  user_pool_id = aws_cognito_user_pool.clients.id
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${local.name}-web"
  user_pool_id = aws_cognito_user_pool.clients.id

  generate_secret                      = false # application JavaScript publique
  prevent_user_existence_errors        = "ENABLED"
  explicit_auth_flows                  = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  callback_urls = ["https://${aws_cloudfront_distribution.frontend.domain_name}/callback"]
  logout_urls   = ["https://${aws_cloudfront_distribution.frontend.domain_name}/"]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 7

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
