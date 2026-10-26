#!/usr/bin/env bash
# Prueba funcional completa en tu PC (Docker Desktop). Uso: ./scripts/prueba_local.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || cp .env.example .env
docker compose --profile local up -d --build
echo "Esperando a que los servicios estén saludables..."
sleep 40
docker compose ps
B=http://localhost:8080
echo; echo "== Catálogo =="; curl -s $B/api/catalogo/productos | head -c 300; echo
echo "== Carrito =="
curl -s -X POST $B/api/carrito/u1/items -H 'Content-Type: application/json' \
  -d '{"sku":"TV-55-001","nombre":"Televisor LED 55","precio":1899,"cantidad":1}'; echo
curl -s $B/api/carrito/u1; echo
echo "== Orden + pago simulado =="
curl -s -X POST $B/api/ordenes/ -H 'Content-Type: application/json' \
  -d '{"userId":"u1","items":[{"sku":"TV-55-001","cantidad":1,"precio":1899}]}'; echo
curl -s "$B/api/ordenes/?userId=u1"; echo
