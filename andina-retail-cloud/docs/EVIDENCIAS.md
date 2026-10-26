# Guía de evidencias del APF2

La rúbrica exige que la evidencia **se vea funcionando en la nube o en el repositorio**.
Toma cada captura con tu usuario y la fecha visibles. Guarda los PNG en `docs/evidencias/`
con el nombre indicado y ejecuta `python scripts/insertar_evidencias.py`: el script los coloca
solo en cada figura y genera `docs/Informe_APF2_Servicios_Cloud_final.docx`.

| Figura | Archivo | Qué mostrar y cómo obtenerlo |
|---|---|---|
| Fig. 4 | `fig04-vpc-rutas.png` | Consola AWS → VPC: `andina-vpc`, las 6 subredes (zona y CIDR) y las 3 tablas de ruteo con IGW, NAT y endpoint S3. Un collage de 2–3 capturas sirve. |
| Fig. 5 | `fig05-computo-datos.png` | EC2: 2 instancias *running* y columna *IPv4 pública* vacía. RDS: *Available* y *Publicly accessible = No*. S3: pestaña *Properties* con versionado. |
| Fig. 7 | `fig07-compose.png` | En la VM (Session Manager): `cd /opt/retail && docker compose ps` y `curl localhost:8080/api/catalogo/productos`. |
| Fig. 8 | `fig08-ecr-alb.png` | ECR con los 5 repositorios y etiqueta `1.0.0`; EC2 → Target groups → `tg-andina-8080` con 2 destinos *healthy*. |
| Fig. 9 | `fig09-commits.png` | `git log --oneline --graph --all` en VS Code o la página del repositorio en GitHub. |
| Fig. 10 | `fig10-security-groups.png` | EC2 → Security Groups: reglas de entrada de `sg-alb`, `sg-app`, `sg-db` (que `sg-db` solo admita 5432 desde `sg-app`). |
| Fig. 11 | `fig11-verificacion.png` | Salida de `./scripts/verificar.sh` (V01, V05, V06, RDS y S3). |
| Fig. 12 | `fig12-pruebas-vm.png` | Salida de `scripts/pruebas_vm.sh` dentro de la VM (V02, V03, V04). |
| Anexo A | `anexo-recursos.png` | Consola AWS: lista de recursos creados con la etiqueta `Proyecto = andina-retail` (Resource Groups → Tag Editor o EC2/VPC filtrados). |
| Anexo A | `anexo-terraform-apply.png` | Final de `terraform apply` con "Apply complete! Resources: N added". |
| Anexo A | `anexo-alb-navegador.png` | Navegador en `http://<alb_dns>/api/catalogo/productos`. |

## Cómo entrar a una VM sin SSH

1. Consola AWS → EC2 → selecciona `vm-app-01` → **Connect** → pestaña **Session Manager** → *Connect*.
   (O con CLI: `aws ssm start-session --target <instance-id>`; los IDs salen de `terraform output vm_ids`.)
2. Dentro de la sesión: `sudo -i` y luego `bash /opt/retail/pruebas_vm.sh` (copia el script con `cat > ... <<'EOF'`
   o ejecútalo línea por línea).

## Resultados de la Tabla 17 (V01–V06)

Anota **Pasa/Falla** según la salida real:

| ID | Dónde se ejecuta | Cómo |
|---|---|---|
| V01 | tu PC | `scripts/verificar.sh` |
| V02, V03, V04 | VM | `scripts/pruebas_vm.sh` (para V04 termina con `sudo reboot` y consulta de nuevo) |
| V05, V06 | tu PC | `scripts/verificar.sh` |

## Tamaño de las imágenes (Tabla 18)

```bash
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -E "ms-|gateway"
```
Copia los valores reales a la tabla (los del informe son referenciales).
