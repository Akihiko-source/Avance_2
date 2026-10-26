const express = require('express');
const { pool, waitForDb } = require('./db');

const app = express();
app.use(express.json());
const PORT = process.env.PORT || 3002;
const PAGOS_URL = process.env.PAGOS_URL || 'http://pagos:3003';
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'ms-ordenes' }));

// RF04 + RF05 - crea la orden y solicita el pago simulado
app.post('/', wrap(async (req, res) => {
  const { userId, items } = req.body;
  if (!userId || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'userId e items son obligatorios' });
  }
  const total = items.reduce((acc, i) => acc + Number(i.precio) * Number(i.cantidad), 0);

  const client = await pool.connect();
  let ordenId;
  try {
    await client.query('BEGIN');
    const o = await client.query(
      `INSERT INTO ordenes (user_id, total, estado) VALUES ($1,$2,'PENDIENTE') RETURNING id`,
      [userId, total]
    );
    ordenId = o.rows[0].id;
    for (const i of items) {
      await client.query(
        `INSERT INTO orden_items (orden_id, sku, cantidad, precio) VALUES ($1,$2,$3,$4)`,
        [ordenId, i.sku, i.cantidad, i.precio]
      );
    }
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK').catch(() => {});
    throw e;
  } finally {
    client.release();
  }

  let estado = 'PAGO_FALLIDO';
  try {
    const r = await fetch(`${PAGOS_URL}/pagos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ orden_id: ordenId, monto: total }),
    });
    const pago = await r.json();
    estado = pago.estado === 'APROBADO' ? 'PAGADA' : 'PAGO_FALLIDO';
  } catch (e) {
    console.error('Error llamando a pagos:', e.message);
  }
  await pool.query('UPDATE ordenes SET estado = $1 WHERE id = $2', [estado, ordenId]);
  res.status(201).json({ id: ordenId, total, estado });
}));

// RF06 - historial por usuario
app.get('/', wrap(async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ error: 'userId es obligatorio' });
  const { rows } = await pool.query('SELECT * FROM ordenes WHERE user_id = $1 ORDER BY id DESC', [userId]);
  res.json(rows);
}));

app.get('/:id', wrap(async (req, res) => {
  const o = await pool.query('SELECT * FROM ordenes WHERE id = $1', [req.params.id]);
  if (!o.rows.length) return res.status(404).json({ error: 'Orden no encontrada' });
  const items = await pool.query('SELECT sku, cantidad, precio FROM orden_items WHERE orden_id = $1', [req.params.id]);
  res.json({ ...o.rows[0], items: items.rows });
}));

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Error interno' });
});

async function init() {
  await waitForDb();
  await pool.query(`
    CREATE TABLE IF NOT EXISTS ordenes (
      id SERIAL PRIMARY KEY,
      user_id VARCHAR(60) NOT NULL,
      total NUMERIC(12,2) NOT NULL,
      estado VARCHAR(20) NOT NULL,
      creada_en TIMESTAMP NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS orden_items (
      id SERIAL PRIMARY KEY,
      orden_id INT NOT NULL REFERENCES ordenes(id),
      sku VARCHAR(40) NOT NULL,
      cantidad INT NOT NULL,
      precio NUMERIC(10,2) NOT NULL
    )`);
  app.listen(PORT, () => console.log(`ms-ordenes escuchando en ${PORT}`));
}
init().catch((e) => { console.error(e); process.exit(1); });
