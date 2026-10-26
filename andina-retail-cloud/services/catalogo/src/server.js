const express = require('express');
const { S3Client, PutObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { pool, waitForDb } = require('./db');

const app = express();
app.use(express.json({ limit: '5mb' }));

const PORT = process.env.PORT || 3000;
const BUCKET = process.env.S3_BUCKET || '';
const s3 = BUCKET ? new S3Client({ region: process.env.AWS_REGION || 'us-east-1' }) : null;

// Envuelve handlers async para que los errores lleguen al middleware de errores
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'ms-catalogo' }));

// RF01 - listar productos, filtro por categoría
app.get('/productos', wrap(async (req, res) => {
  const { categoria } = req.query;
  const { rows } = categoria
    ? await pool.query('SELECT * FROM productos WHERE categoria = $1 ORDER BY id', [categoria])
    : await pool.query('SELECT * FROM productos ORDER BY id');
  res.json(rows);
}));

// RF02 - detalle de un producto
app.get('/productos/:id', wrap(async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM productos WHERE id = $1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Producto no encontrado' });
  res.json(rows[0]);
}));

// Crear producto (sirve para la prueba de persistencia V04)
app.post('/productos', wrap(async (req, res) => {
  const { sku, nombre, categoria, precio, stock = 0 } = req.body;
  if (!sku || !nombre || !categoria || precio == null) {
    return res.status(400).json({ error: 'sku, nombre, categoria y precio son obligatorios' });
  }
  const { rows } = await pool.query(
    `INSERT INTO productos (sku, nombre, categoria, precio, stock)
     VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [sku, nombre, categoria, precio, stock]
  );
  res.status(201).json(rows[0]);
}));

// RF08 - cargar imagen al bucket S3 (cuerpo: { "contenidoBase64": "..." })
app.post('/productos/:id/imagen', wrap(async (req, res) => {
  if (!s3) return res.status(503).json({ error: 'S3_BUCKET no configurado' });
  const key = `media/producto-${req.params.id}.jpg`;
  const body = Buffer.from(req.body.contenidoBase64 || '', 'base64');
  await s3.send(new PutObjectCommand({ Bucket: BUCKET, Key: key, Body: body, ContentType: 'image/jpeg' }));
  await pool.query('UPDATE productos SET imagen_key = $1 WHERE id = $2', [key, req.params.id]);
  res.status(201).json({ key });
}));

// Prueba V03 - verifica acceso al bucket desde la red privada
app.get('/media', wrap(async (_req, res) => {
  if (!s3) return res.status(503).json({ error: 'S3_BUCKET no configurado' });
  const out = await s3.send(new ListObjectsV2Command({ Bucket: BUCKET, Prefix: 'media/' }));
  res.json((out.Contents || []).map((o) => o.Key));
}));

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Error interno' });
});

async function init() {
  await waitForDb();
  await pool.query(`
    CREATE TABLE IF NOT EXISTS productos (
      id SERIAL PRIMARY KEY,
      sku VARCHAR(40) UNIQUE NOT NULL,
      nombre VARCHAR(150) NOT NULL,
      categoria VARCHAR(60) NOT NULL,
      precio NUMERIC(10,2) NOT NULL,
      stock INT NOT NULL DEFAULT 0,
      imagen_key VARCHAR(200)
    )`);
  const { rows } = await pool.query('SELECT COUNT(*)::int AS n FROM productos');
  if (rows[0].n === 0) {
    await pool.query(`
      INSERT INTO productos (sku, nombre, categoria, precio, stock) VALUES
      ('TV-55-001','Televisor LED 55"','Televisores',1899.00,25),
      ('LAV-9-002','Lavadora 9 kg','Lavado',1499.00,18),
      ('REF-300-003','Refrigeradora 300 L','Refrigeración',2199.00,12),
      ('LAP-15-004','Laptop 15" 16 GB RAM','Computo',3299.00,30),
      ('CEL-128-005','Smartphone 128 GB','Celulares',1199.00,50),
      ('LIC-700-006','Licuadora 700 W','Cocina',189.00,80)`);
  }
  app.listen(PORT, () => console.log(`ms-catalogo escuchando en ${PORT}`));
}
init().catch((e) => { console.error(e); process.exit(1); });
