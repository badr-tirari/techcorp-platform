output "frontend_url" {
  description = "Site client (CloudFront -> S3)"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "api_url" {
  description = "API (CloudFront -> ALB -> ECS)"
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}

output "alb_dns_name" {
  value = aws_lb.api.dns_name
}

output "frontend_bucket" {
  value = aws_s3_bucket.frontend.bucket
}

output "documents_bucket" {
  value = aws_s3_bucket.documents.bucket
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service" {
  value = aws_ecs_service.api.name
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "rds_secret_arn" {
  description = "Identifiants PostgreSQL (Secrets Manager)"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.clients.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "cognito_hosted_ui" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "dev_instance_id" {
  description = "Connexion : aws ssm start-session --target <id>"
  value       = aws_instance.dev.id
}

output "github_actions_role_arn" {
  description = "A renseigner dans la variable GitHub AWS_ROLE_ARN"
  value       = aws_iam_role.github_deploy.arn
}

output "cloudwatch_dashboard" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
