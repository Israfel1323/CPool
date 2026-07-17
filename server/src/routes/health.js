import { Router } from 'express';
import { query } from '../db/pool.js';

const router = Router();

router.get('/', async (_req, res) => {
  try {
    await query('SELECT 1');
    res.json({ status: 'ok', service: 'cpool-api', database: 'connected' });
  } catch (err) {
    res.status(503).json({
      status: 'degraded',
      service: 'cpool-api',
      database: 'disconnected',
      error: err.message,
    });
  }
});

export default router;
