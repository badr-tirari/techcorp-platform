#!/usr/bin/env bash
# create_server.sh
# -----------------
# Création scriptée du serveur (alternative "one-shot" à Terraform), utile pour
# démontrer l'automatisation par script (compétence CCP1) et pour un test rapide.
# Le déploiement de référence pour ce projet reste `terraform apply`.
set -euo pipefail

PROJECT_NAME="techcorp-platform"
REGION="eu-west-3"
INSTANCE_TYPE="t3.medium"
KEY_NAME="${PROJECT_NAME}-key"
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
            "Name=virtualization-type,Values=hvm" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text --region "$REGION")

echo "AMI Ubuntu 22.04 la plus récente : $AMI_ID"

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}-server}]" \
  --region "$REGION" \
  --query 'Instances[0].InstanceId' --output text)

echo "Instance créée : $INSTANCE_ID"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text --region "$REGION")

echo "Instance en cours d'exécution : $INSTANCE_ID"
echo "IP publique : $PUBLIC_IP"
echo "-> Capture d'écran à garder : cette sortie terminal (Instance ID + IP publique)."
