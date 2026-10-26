locals {
  repos = ["ms-catalogo", "ms-carrito", "ms-ordenes", "ms-pagos", "retail-gateway"]
}

resource "aws_ecr_repository" "repos" {
  for_each             = toset(local.repos)
  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}
