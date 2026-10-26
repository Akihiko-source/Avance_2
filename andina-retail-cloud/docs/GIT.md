# Flujo Git recomendado (trabajo individual)

Como el trabajo es individual, el historial debe mostrar **avance real y ordenado**: ramas por funcionalidad,
commits pequeños con Conventional Commits y *pull requests* hacia `main` (aunque los apruebes tú misma).

```bash
git init -b main
git remote add origin https://github.com/<tu-usuario>/andina-retail-cloud.git

# 1) base del repositorio
git add .gitignore README.md .env.example .vscode
git commit -m "chore: estructura inicial, README y .gitignore"

# 2) infraestructura de red
git switch -c feat/network
git add infra/versions.tf infra/variables.tf infra/network.tf
git commit -m "feat: agrega VPC, subredes publicas, privadas y aisladas"
git add infra/security.tf
git commit -m "feat: agrega Security Groups con minimo privilegio"

# 3) datos y computo
git switch -c feat/datos-computo main
git add infra/data.tf infra/iam.tf infra/registry.tf
git commit -m "feat: agrega RDS, S3, ECR y roles IAM"
git add infra/compute.tf infra/outputs.tf infra/user-data.sh.tftpl infra/terraform.tfvars.example
git commit -m "feat: agrega EC2, ALB y script de arranque"

# 4) microservicios y docker
git switch -c feat/microservicios main
git add services/catalogo && git commit -m "feat: servicio de catalogo con PostgreSQL y S3"
git add services/carrito  && git commit -m "feat: servicio de carrito con Redis"
git add services/ordenes  && git commit -m "feat: servicio de ordenes"
git add services/pagos    && git commit -m "feat: servicio de pagos (pasarela simulada)"
git add gateway docker-compose.yml db && git commit -m "feat: gateway Nginx y docker compose"

# 5) scripts y documentacion
git switch -c docs/informe-apf2 main
git add scripts && git commit -m "feat: scripts de despliegue y verificacion"
git add docs && git commit -m "docs: informe APF2 y guia de evidencias"
```

Sube cada rama (`git push -u origin <rama>`), abre el *pull request* en GitHub y haz *merge* a `main`.
Haz commits reales conforme avances (no los fuerces todos el mismo día): el historial se revisa en la sustentación.

Antes de cada commit: `git status` y comprueba que no aparezcan `.env`, `terraform.tfvars` ni `*.tfstate`.
