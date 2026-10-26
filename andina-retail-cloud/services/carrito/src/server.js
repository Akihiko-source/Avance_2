const express = require('express');
const { createClient } = require('redis');

const app = express();
app.use(express.json());
const PORT = process.env.PORT || 3001;

const redis = createClient({ url: process.env.REDIS_URL || 'redis://redis:6379' });
redis.on('error', (e) => console.error('Redis:', e.message));

const key = (userId) => `carrito:${userId}`;
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

app.get('/health', async (_req, res) => {
  try {
    await redis.ping();
    res.json({ status: 'ok', service: 'ms-carrito' });
  } catch {
    res.status(503).json({ status: 'redis no disponible' });
  }
});

// RF03 - ver carrito
app.get('/:userId', wrap(async (req, res) => {
  const items = await redis.hGetAll(key(req.params.userId));
  res.json(Object.values(items).map((v) => JSON.parse(v)));
}));

// agregar o modificar un producto
app.post('/:userId/items', wrap(async (req, res) => {
  const { sku, nombre, precio, cantidad } = req.body;
  if (!sku || precio == null || !cantidad) {
    return res.status(400).json({ error: 'sku, precio y cantidad son obligatorios' });
  }
  await redis.hSet(key(req.params.userId), sku, JSON.stringify({ sku, nombre, precio, cantidad }));
  res.status(201).json({ sku, cantidad });
}));

app.delete('/:userId/items/:sku', wrap(async (req, res) => {
  await redis.hDel(key(req.params.userId), req.params.sku);
  res.status(204).end();
}));

app.delete('/:userId', wrap(async (req, res) => {
  await redis.del(key(req.params.userId));
  res.status(204).end();
}));

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Error interno' });
});

redis.connect().then(() => {
  app.listen(PORT, () => console.log(`ms-carrito escuchando en ${PORT}`));
}).catch((e) => { console.error(e); process.exit(1); });
