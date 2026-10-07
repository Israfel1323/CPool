import { Router } from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

const CATEGORIES = new Set([
    'Payment',
    'Ride',
    'Booking',
    'Account',
    'Safety',
    'Other',
]);

const clean = (value) => (typeof value === 'string' ? value.trim() : '');

router.get('/tickets', requireAuth, async (req, res) => {
    const result = await query(
        `SELECT id, category, description, status, commute_id,
            created_at, updated_at, resolved_at
     FROM support_tickets
     WHERE user_id = $1
     ORDER BY created_at DESC`,
        [req.user.id],
    );

    res.json({ tickets: result.rows });
});

router.post('/tickets', requireAuth, async (req, res) => {
    const category = clean(req.body?.category);
    const description = clean(req.body?.description);
    const commuteId = clean(req.body?.commute_id) || null;

    if (!CATEGORIES.has(category)) {
        return res.status(400).json({ error: 'Invalid support category.' });
    }

    if (description.length < 5) {
        return res.status(400).json({
            error: 'Please describe the issue in at least 5 characters.',
        });
    }

    if (commuteId) {
        const ride = await query(
            `SELECT c.id
       FROM commutes c
       WHERE c.id = $1
         AND (
           c.driver_id = $2
           OR EXISTS (
             SELECT 1
             FROM ride_bookings rb
             WHERE rb.commute_id = c.id
               AND rb.passenger_id = $2
           )
         )
       LIMIT 1`,
            [commuteId, req.user.id],
        );

        if (ride.rowCount === 0) {
            return res.status(403).json({
                error: 'You can only attach a ride you are part of.',
            });
        }
    }

    const ticket = await query(
        `INSERT INTO support_tickets
       (user_id, commute_id, category, description)
     VALUES ($1, $2, $3, $4)
     RETURNING id, user_id, commute_id, category, description,
               status, created_at, updated_at, resolved_at`,
        [req.user.id, commuteId, category, description],
    );

    await query(
        `INSERT INTO support_messages
       (ticket_id, sender_id, sender_role, message)
     VALUES ($1, $2, 'user', $3)`,
        [ticket.rows[0].id, req.user.id, description],
    );

    return res.status(201).json({ ticket: ticket.rows[0] });
});

router.get('/tickets/:id', requireAuth, async (req, res) => {
    const ticket = await query(
        `SELECT id, category, description, status, commute_id,
            created_at, updated_at, resolved_at
     FROM support_tickets
     WHERE id = $1 AND user_id = $2
     LIMIT 1`,
        [req.params.id, req.user.id],
    );

    if (ticket.rowCount === 0) {
        return res.status(404).json({ error: 'Ticket not found.' });
    }

    const messages = await query(
        `SELECT id, sender_id, sender_role, message, created_at
     FROM support_messages
     WHERE ticket_id = $1
     ORDER BY created_at ASC`,
        [req.params.id],
    );

    return res.json({ ticket: ticket.rows[0], messages: messages.rows });
});
router.post('/tickets/:id/reply', requireAuth, async (req, res) => {
    const message = clean(req.body?.message);

    if (!message) {
        return res.status(400).json({
            error: 'A reply message is required.',
        });
    }

    const ticket = await query(
        `SELECT id, status
         FROM support_tickets
         WHERE id = $1
           AND user_id = $2
         LIMIT 1`,
        [req.params.id, req.user.id],
    );

    if (ticket.rowCount === 0) {
        return res.status(404).json({
            error: 'Ticket not found.',
        });
    }

    if (ticket.rows[0].status === 'resolved') {
        return res.status(409).json({
            error: 'Resolved tickets cannot receive new replies.',
        });
    }

    const result = await query(
        `INSERT INTO support_messages
            (ticket_id, sender_id, sender_role, message)
         VALUES ($1, $2, 'user', $3)
         RETURNING id, ticket_id, sender_id, sender_role, message, created_at`,
        [req.params.id, req.user.id, message],
    );

    return res.status(201).json({
        message: result.rows[0],
    });
});
export default router;
