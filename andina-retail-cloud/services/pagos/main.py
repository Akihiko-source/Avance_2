import os
import time

import psycopg2
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="ms-pagos")


def get_conn():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "5432")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        dbname=os.environ.get("DB_NAME", "pagos"),
        sslmode="require" if os.environ.get("DB_SSL") == "require" else "disable",
    )


@app.on_event("startup")
def init_db():
    for intento in range(1, 31):
        try:
            conn = get_conn()
            with conn, conn.cursor() as cur:
                cur.execute(
                    """CREATE TABLE IF NOT EXISTS pagos (
                        id SERIAL PRIMARY KEY,
                        orden_id INT NOT NULL,
                        monto NUMERIC(12,2) NOT NULL,
                        estado VARCHAR(20) NOT NULL,
                        creado_en TIMESTAMP NOT NULL DEFAULT now())"""
                )
            conn.close()
            return
        except Exception as e:  # base de datos aún no disponible
            print(f"Esperando base de datos ({intento}/30): {e}", flush=True)
            time.sleep(3)
    raise RuntimeError("No se pudo conectar a la base de datos")


class PagoIn(BaseModel):
    orden_id: int
    monto: float


@app.get("/health")
def health():
    return {"status": "ok", "service": "ms-pagos"}


@app.post("/pagos", status_code=201)
def crear_pago(p: PagoIn):
    # Pasarela simulada: se rechazan montos mayores a 10 000
    estado = "APROBADO" if p.monto <= 10000 else "RECHAZADO"
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO pagos (orden_id, monto, estado) VALUES (%s,%s,%s) RETURNING id",
                (p.orden_id, p.monto, estado),
            )
            pago_id = cur.fetchone()[0]
    finally:
        conn.close()
    return {"id": pago_id, "orden_id": p.orden_id, "estado": estado}


@app.get("/pagos/{orden_id}")
def ver_pagos(orden_id: int):
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "SELECT id, monto, estado FROM pagos WHERE orden_id = %s ORDER BY id", (orden_id,)
            )
            return [{"id": r[0], "monto": float(r[1]), "estado": r[2]} for r in cur.fetchall()]
    finally:
        conn.close()
