resource "aws_ecr_repository" "repos" {
  for_each = toset([
    "oauth-api",
    "web-v2-dashboard", 
    "integrated-dashboard",
    "map-api",
    "energy-api",
    "my-web",
    "kma-api",
    "dr-worker"
  ])
  
  name = "production/${each.key}"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  image_tag_mutability = "MUTABLE"
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = {
    Name        = "production-${each.key}"
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "repo_policy" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

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
