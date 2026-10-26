#!/usr/bin/env bash
# Se ejecuta DENTRO de una VM (sesión de Session Manager): pruebas V02, V03 y V04.
set -uo pipefail
cd /opt/retail
set -a; source .env; set +a

echo "== V02: conexión a RDS desde la red privada =="
PGPASSWORD="$DB_PASSWORD" psql "host=$DB_HOST user=$DB_USER dbname=catalogo sslmode=require" -c "select 1 as conexion_ok"

echo; echo "== V03: acceso al bucket S3 con el rol de la VM =="
aws s3 cp /etc/hostname "s3://$S3_BUCKET/media/prueba.txt"
aws s3 ls "s3://$S3_BUCKET/media/"

echo; echo "== docker compose ps =="
docker compose ps

echo; echo "== V04: persistencia (crear producto, reiniciar y consultar) =="
curl -s -X POST localhost:8080/api/catalogo/productos -H 'Content-Type: application/json' \
  -d '{"sku":"PERS-001","nombre":"Producto de persistencia","categoria":"Prueba","precio":99.90,"stock":5}'; echo
docker compose restart
sleep 25
curl -s localhost:8080/api/catalogo/productos | grep -o 'PERS-001' && echo "OK: el dato persiste tras reiniciar los contenedores"
echo "Ahora ejecuta: sudo reboot   (y luego vuelve a consultar el producto)"
