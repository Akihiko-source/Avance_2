#!/usr/bin/env bash
# Pruebas V01-V06 del informe (sección 5.5). Ejecutar desde tu PC con AWS CLI configurado.
# La prueba V02/V03/V04 requiere una sesión SSM en una VM: ver docs/EVIDENCIAS.md
set -uo pipefail
cd "$(dirname "$0")/../infra"
ALB=$(terraform output -raw alb_dns)
RDS=$(terraform output -raw rds_endpoint)
BUCKET=$(terraform output -raw s3_bucket)

echo "== V01: las VMs no tienen IP pública =="
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,PublicIpAddress]" --output table

echo; echo "== V05: destinos del balanceador =="
TG=$(aws elbv2 describe-target-groups --names tg-andina-8080 --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn "$TG" \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table

echo; echo "== V06: RDS no accesible desde Internet (debe agotar el tiempo) =="
timeout 6 bash -c "echo > /dev/tcp/${RDS}/5432" 2>&1 && echo "ALERTA: RDS es accesible" || echo "OK: sin acceso desde Internet"

echo; echo "== RDS: publicly accessible =="
aws rds describe-db-instances --db-instance-identifier db-andina \
  --query 'DBInstances[0].[DBInstanceStatus,PubliclyAccessible,StorageEncrypted]' --output table

echo; echo "== S3: versionado y bloqueo público =="
aws s3api get-bucket-versioning --bucket "$BUCKET"
aws s3api get-public-access-block --bucket "$BUCKET"

echo; echo "== Smoke test a través del ALB =="
curl -s "http://${ALB}/health"; echo
curl -s "http://${ALB}/api/catalogo/productos" | head -c 400; echo
