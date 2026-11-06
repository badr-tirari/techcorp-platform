# Registre d'images du back-end (Activité Type 2, question 3)

resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE" # "latest" + tag immuable par SHA de commit
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true # analyse de vulnérabilités à chaque push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# FinOps : on ne conserve que les 10 dernières images
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Garder les 10 dernieres images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
