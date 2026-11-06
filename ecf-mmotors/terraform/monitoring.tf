# Activité Type 3 — Supervision (CloudWatch)
#   1. 2 métriques hardware   : CPU et mémoire ECS, CPU et stockage libre RDS
#   2. 2 métriques applicatives : erreurs dans les logs, chemin critique (5xx, latence p95, cibles saines)
#   3. 2 métriques FinOps     : budget AWS (réel + prévisionnel), frais estimés du mois
#   4. Alerting                : toutes les alarmes -> SNS -> e-mail

# ===========================================================================
# Canal d'alerte
# ===========================================================================
resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
  ecs_dims = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.api.name
  }
  alb_dims = {
    LoadBalancer = aws_lb.api.arn_suffix
  }
  tg_dims = {
    LoadBalancer = aws_lb.api.arn_suffix
    TargetGroup  = aws_lb_target_group.api.arn_suffix
  }
  rds_dims = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

# ===========================================================================
# 1. Hardware
# ===========================================================================
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.name}-HW-ecs-cpu-high"
  alarm_description   = "[HARDWARE] CPU moyen du service ECS > 80 % pendant 10 min"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = local.ecs_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${local.name}-HW-ecs-memory-high"
  alarm_description   = "[HARDWARE] Memoire moyenne du service ECS > 85 % pendant 10 min"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = local.ecs_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name}-HW-rds-cpu-high"
  alarm_description   = "[HARDWARE] CPU PostgreSQL > 80 % pendant 15 min"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = local.rds_dims
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${local.name}-HW-rds-free-storage-low"
  alarm_description   = "[HARDWARE] Stockage libre PostgreSQL < 2 Gio"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = local.rds_dims
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ===========================================================================
# 2. Applicatif
# ===========================================================================

# 2a. Erreurs dans les logs applicatifs (niveau ERROR, exceptions Python)
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${local.name}-app-errors"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "?ERROR ?Traceback ?CRITICAL"

  metric_transformation {
    name          = "ApplicationErrorCount"
    namespace     = "MMotors/Application"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "${local.name}-APP-error-logs"
  alarm_description   = "[APPLICATIF] Plus de 5 erreurs dans les logs en 5 min"
  namespace           = "MMotors/Application"
  metric_name         = "ApplicationErrorCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# 2b. Chemin critique : dépôt et suivi de dossier (API derrière l'ALB)
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name}-APP-api-5xx"
  alarm_description   = "[APPLICATIF] Chemin critique : plus de 10 reponses 5xx en 5 min"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = local.tg_dims
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "api_latency_p95" {
  alarm_name          = "${local.name}-APP-api-latency-p95"
  alarm_description   = "[APPLICATIF] Chemin critique : latence p95 > 1 s pendant 10 min"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = local.tg_dims
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "api_no_healthy_target" {
  alarm_name          = "${local.name}-APP-api-down"
  alarm_description   = "[APPLICATIF] Service indisponible : aucune tache ECS saine derriere l'ALB"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = local.tg_dims
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ===========================================================================
# 3. FinOps
# ===========================================================================

# 3a. Budget mensuel : alerte à 80 % de la dépense réelle et à 100 % du prévisionnel
resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-budget-mensuel"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

# 3b. Frais estimés du mois (métrique AWS/Billing, région us-east-1 uniquement).
# Prérequis : "Recevoir les alertes de facturation" activé dans la console Billing.
resource "aws_sns_topic" "billing" {
  provider = aws.us_east_1
  name     = "${local.name}-billing-alerts"
}

resource "aws_sns_topic_subscription" "billing_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.billing.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  provider            = aws.us_east_1
  alarm_name          = "${local.name}-FINOPS-estimated-charges"
  alarm_description   = "[FINOPS] Frais AWS estimes du mois > seuil"
  namespace           = "AWS/Billing"
  metric_name         = "EstimatedCharges"
  dimensions          = { Currency = "USD" }
  statistic           = "Maximum"
  period              = 21600
  evaluation_periods  = 1
  threshold           = var.billing_alarm_threshold_usd
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.billing.arn]
}

# 3c. Indicateur FinOps d'usage : VM de dev allumée hors plage horaire (CPU > 0 la nuit)
#     -> visible sur le tableau de bord (heures de fonctionnement réelles).

# ===========================================================================
# Tableau de bord
# ===========================================================================
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name}-supervision"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 1,
        properties = { markdown = "# M-Motors - Supervision (hardware / applicatif / FinOps)" }
      },
      {
        type = "metric", x = 0, y = 1, width = 12, height = 6,
        properties = {
          title  = "HW - ECS CPU / Memoire (%)"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.api.name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
          ]
          annotations = { horizontal = [{ value = 80, label = "Seuil CPU" }] }
        }
      },
      {
        type = "metric", x = 12, y = 1, width = 12, height = 6,
        properties = {
          title  = "HW - RDS CPU (%) et stockage libre (octets)"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier],
            [".", "FreeStorageSpace", ".", ".", { yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 7, width = 8, height = 6,
        properties = {
          title  = "APP - Erreurs dans les logs"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["MMotors/Application", "ApplicationErrorCount"],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 7, width = 8, height = 6,
        properties = {
          title  = "APP - Chemin critique : requetes / 5xx"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.api.arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.api.arn_suffix, "TargetGroup", aws_lb_target_group.api.arn_suffix],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 7, width = 8, height = 6,
        properties = {
          title  = "APP - Latence p95 (s)"
          region = var.aws_region
          stat   = "p95"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.api.arn_suffix, "TargetGroup", aws_lb_target_group.api.arn_suffix],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 13, width = 12, height = 6,
        properties = {
          title  = "FINOPS - Frais estimes du mois (USD)"
          region = "us-east-1"
          stat   = "Maximum"
          period = 21600
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD"],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 13, width = 12, height = 6,
        properties = {
          title  = "FINOPS - VM dev : activite CPU (doit etre nulle 20h-08h et le week-end)"
          region = var.aws_region
          stat   = "Average"
          period = 3600
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.dev.id],
          ]
        }
      },
    ]
  })
}
