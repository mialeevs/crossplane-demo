# ECR Repository Configuration

resource "aws_ecr_repository" "order_worker" {
  name                 = "${local.name_prefix}-order-worker"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Set to false in production

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-order-worker"
    }
  )
}

resource "aws_ecr_lifecycle_policy" "order_worker_policy" {
  repository = aws_ecr_repository.order_worker.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
