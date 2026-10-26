#!/usr/bin/env bash
# Construye las 5 imágenes y las publica en Amazon ECR.
# Uso: ./scripts/build_push.sh 1.0.0
set -euo pipefail
TAG="${1:-1.0.0}"
REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

build() { # nombre ruta
  docker build -t "${REGISTRY}/$1:${TAG}" "$2"
  docker push "${REGISTRY}/$1:${TAG}"
}

build ms-catalogo    services/catalogo
build ms-carrito     services/carrito
build ms-ordenes     services/ordenes
build ms-pagos       services/pagos
build retail-gateway gateway

echo "Imágenes publicadas en ${REGISTRY} con la etiqueta ${TAG}"
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -E "ms-|retail-gateway" || true
