# Andina Retail Cloud – Plataforma de comercio electrónico con microservicios

Proyecto del curso **Servicios Cloud** (Tema 1: microservicios en Kubernetes).
Entrega **APF2**: red virtual, cómputo, almacenamiento, contenedores y repositorio en AWS (`us-east-1`).

## Arquitectura (resumen)

```
Internet → ALB (subredes públicas) → 2 VMs EC2 (subredes privadas, Docker Compose)
                                      ├─ gateway Nginx :8080
                                      ├─ ms-catalogo :3000  ┐
                                      ├─ ms-carrito  :3001  ├─ RDS PostgreSQL (subred aislada)
                                      ├─ ms-ordenes  :3002  │
                                      ├─ ms-pagos    :3003  ┘
                                      └─ redis (carrito)     S3 (imágenes, vía VPC Endpoint)
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `services/` | Código y Dockerfile (multi-stage) de catálogo, carrito, órdenes y pagos |
| `gateway/` | Nginx que enruta `/api/<servicio>/` y sirve la interfaz web (`index.html`) |
| `infra/` | Terraform: VPC, subredes, rutas, NAT, SG, EC2, ALB, RDS, S3, ECR |
| `scripts/` | Despliegue, publicación de imágenes y pruebas de verificación |
| `docs/` | Informe, evidencias y guías |
| `k8s/`, `monitoring/`, `tests/load/` | Reservados para APF3 y entrega final |

## Requisitos

Docker Desktop, Node.js 20 (opcional), AWS CLI v2, Terraform ≥ 1.6, Git y VS Code.
Credenciales de AWS Academy / Free Tier configuradas (`aws configure` o variables de sesión).

## 1. Ejecutar en local (sin AWS)

```bash
cp .env.example .env            # ajusta DB_PASSWORD
docker compose --profile local up -d --build
docker compose ps               # los 6 servicios deben estar "healthy"
curl http://localhost:8080/api/catalogo/productos
```

Prueba completa (catálogo → carrito → orden → pago): `./scripts/prueba_local.sh`

| Endpoint (vía gateway :8080) | Descripción |
|---|---|
| `GET /api/catalogo/productos?categoria=` | Lista de productos (RF01) |
| `GET /api/catalogo/productos/{id}` | Detalle (RF02) |
| `POST /api/catalogo/productos` | Crear producto |
| `POST /api/catalogo/productos/{id}/imagen` | Subir imagen a S3 (RF08) |
| `GET/POST/DELETE /api/carrito/{userId}[/items]` | Carrito en Redis (RF03) |
| `POST /api/ordenes/` · `GET /api/ordenes/?userId=` | Crear orden y pago simulado / historial (RF04–RF06) |
| `GET /health` en cada servicio | Health check (RF07) |

## 2. Desplegar en AWS

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # define db_password (no se sube a Git)
cd ..
./scripts/deploy.sh 1.0.0
```

`deploy.sh` hace: (1) crea los repositorios ECR, (2) construye y publica las imágenes,
(3) crea red, RDS, S3, VMs y ALB. Al terminar muestra `alb_dns`:

```bash
curl http://<alb_dns>/health
curl http://<alb_dns>/api/catalogo/productos
```

- **AWS Academy:** `use_lab_role = true` (por defecto) usa el `LabInstanceProfile` existente.
- **Cuenta Free Tier:** `use_lab_role = false` crea el rol de mínimo privilegio (`infra/iam.tf`).
- **HTTPS:** define `certificate_arn` (certificado de ACM) para activar el listener 443.

Si las VMs arrancaron antes de publicar las imágenes, entra por Session Manager y ejecuta
`sudo /opt/retail/start.sh`.

## 3. Verificación (evidencias del APF2)

Ver [`docs/EVIDENCIAS.md`](docs/EVIDENCIAS.md): comandos y capturas exactas para cada criterio de la rúbrica.

## 4. Destruir el entorno (evita gastar créditos)

```bash
cd infra && terraform destroy
```

## Seguridad

- `.env`, `terraform.tfvars`, `*.tfstate` y llaves están en `.gitignore`.
- Sin IP pública en VMs ni RDS; sin SSH (acceso por SSM); Security Groups por referencia.
- Contraseña de la BD en Parameter Store (SecureString); TLS obligatorio en RDS.
