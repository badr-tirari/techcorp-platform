# Activité Type 2, question 5 —
# "Créez la policy qui permet la lecture des documents d'achat/location stockés
#  en S3 depuis ECS."
#
# Principe du moindre privilège :
#  - attachée au TASK ROLE (le code Python), pas à l'execution role ;
#  - limitée au seul bucket des dossiers et au préfixe "dossiers/" ;
#  - lecture seule (List + Get), aucun Put/Delete ;
#  - kms:Decrypt sur la seule clé du bucket, et seulement via S3 ;
#  - accès refusé hors du point de terminaison VPC S3 (pas de sortie Internet).

data "aws_iam_policy_document" "ecs_read_documents" {
  statement {
    sid       = "ListDossiersPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.documents.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["dossiers/*"]
    }
  }

  statement {
    sid    = "ReadDossierDocuments"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTagging",
    ]
    resources = ["${aws_s3_bucket.documents.arn}/dossiers/*"]
  }

  statement {
    sid       = "DecryptWithDocumentsKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.documents.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "DenyOutsideVpcEndpoint"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.documents.arn, "${aws_s3_bucket.documents.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.s3.id]
    }
  }
}

resource "aws_iam_policy" "ecs_read_documents" {
  name        = "${local.name}-ecs-read-dossiers"
  description = "Lecture seule des dossiers d'achat/location (S3) par les taches ECS"
  policy      = data.aws_iam_policy_document.ecs_read_documents.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_read_documents" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_read_documents.arn
}
