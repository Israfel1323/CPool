import { Router } from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.get('/:commuteId', requireAuth, async (req, res) => {
  const result = await query(
    `SELECT m.*, p.display_name AS sender_name
     FROM chat_messages m
     JOIN profiles p ON p.id = m.sender_id
     WHERE m.commute_id = $1
     ORDER BY m.created_at ASC
     LIMIT 200`,
    [req.params.commuteId],
  );
  res.json({ messages: result.rows });
});

router.post('/:commuteId', requireAuth, async (req, res) => {
  const { body } = req.body;
  if (!body?.trim()) return res.status(400).json({ error: 'Message body required' });

  const result = await query(
    `INSERT INTO chat_messages (commute_id, sender_id, body)
     VALUES ($1, $2, $3) RETURNING *`,
    [req.params.commuteId, req.user.id, body.trim()],
  );
  res.status(201).json({ message: result.rows[0] });
});

export default router;
