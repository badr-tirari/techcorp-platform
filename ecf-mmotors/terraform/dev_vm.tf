# Question 2d — Machine virtuelle de développement (EC2)
#  - Spot instance (jusqu'à -70 % par rapport au prix à la demande)
#  - Programmée : arrêt 20h-08h en semaine et tout le week-end
#    (EventBridge Scheduler, fuseau Europe/Paris)
#  - Aucune règle entrante : administration via SSM Session Manager (pas de SSH)

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dev" {
  name               = "${local.name}-dev-vm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "dev_ssm" {
  role       = aws_iam_role.dev.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "dev_cw_agent" {
  role       = aws_iam_role.dev.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "dev" {
  name = "${local.name}-dev-vm"
  role = aws_iam_role.dev.name
}

resource "aws_instance" "dev" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.dev_instance_type
  subnet_id              = aws_subnet.private_app[0].id
  vpc_security_group_ids = [aws_security_group.dev.id]
  iam_instance_profile   = aws_iam_instance_profile.dev.name

  # Instance Spot persistante : "stop" (et non "terminate") en cas de reprise
  # par AWS, ce qui autorise aussi l'arrêt / redémarrage planifié.
  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = "persistent"
      instance_interruption_behavior = "stop"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 obligatoire
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOT
    #!/bin/bash
    dnf -y update --security
    dnf -y install docker git python3.11 python3.11-pip postgresql16 amazon-cloudwatch-agent
    systemctl enable --now docker
    usermod -aG docker ec2-user
  EOT

  tags = {
    Name     = "${local.name}-dev"
    Role     = "dev"
    Schedule = "lun-ven 08h-20h Europe/Paris"
  }
}

# ---------------------------------------------------------------------------
# Planification (EventBridge Scheduler)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.name}-dev-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    actions   = ["ec2:StartInstances", "ec2:StopInstances"]
    resources = [aws_instance.dev.arn]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "start-stop-dev-vm"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}

# Arrêt du lundi au vendredi à 20h00 (la VM reste éteinte tout le week-end)
resource "aws_scheduler_schedule" "dev_stop" {
  name                         = "${local.name}-dev-stop"
  description                  = "Arret VM dev 20h lun-ven"
  schedule_expression          = "cron(0 20 ? * MON-FRI *)"
  schedule_expression_timezone = var.schedule_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = [aws_instance.dev.id] })
  }
}

# Démarrage du lundi au vendredi à 08h00
resource "aws_scheduler_schedule" "dev_start" {
  name                         = "${local.name}-dev-start"
  description                  = "Demarrage VM dev 8h lun-ven"
  schedule_expression          = "cron(0 8 ? * MON-FRI *)"
  schedule_expression_timezone = var.schedule_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = [aws_instance.dev.id] })
  }
}
