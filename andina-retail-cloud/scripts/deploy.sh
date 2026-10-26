#!/usr/bin/env bash
# Despliegue completo en 3 pasos (ECR -> imágenes -> resto de la infraestructura)
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${1:-1.0.0}"

cd infra
terraform init
terraform apply -auto-approve -target=aws_ecr_repository.repos
cd ..

./scripts/build_push.sh "$TAG"

cd infra
terraform apply -auto-approve -var "image_tag=${TAG}"
terraform output
