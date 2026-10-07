import { Router } from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

/*
 * Verify that the current user and participant are allowed
 * to have a private chat for this commute.
 *
 * Allowed:
 *   Driver <-> confirmed passenger
 *
 * Not allowed:
 *   Passenger <-> passenger
 *   Pending booking
 *   Rejected booking
 *   Boarded passenger
 *   Unrelated users
 */
async function getChatAccess(commuteId, currentUserId, participantId) {
  const result = await query(
    `SELECT
       c.id AS commute_id,
       c.driver_id,
       rb.passenger_id,
       rb.status AS booking_status
     FROM commutes c
     JOIN ride_bookings rb
       ON rb.commute_id = c.id
     WHERE c.id = $1
       AND (
         (
           c.driver_id = $3
           AND rb.passenger_id = $2
         )
         OR
         (
           c.driver_id = $2
           AND rb.passenger_id = $3
         )
       )
     LIMIT 1`,
    [commuteId, participantId, currentUserId],
  );

  if (result.rows.length === 0) {
    return null;
  }

  const row = result.rows[0];

  if (row.booking_status !== 'confirmed') {
    return null;
  }

  return row;
}
router.get('/unread', requireAuth, async (req, res) => {
  try {
    const currentUserId = req.user.id;

    const result = await query(
      `SELECT
         m.commute_id,
         m.sender_id AS participant_id,
         p.display_name AS participant_name,
         COUNT(*)::int AS unread_count,
         MAX(m.created_at) AS latest_message_at
       FROM chat_messages m
       JOIN commutes c
         ON c.id = m.commute_id
       JOIN ride_bookings rb
         ON rb.commute_id = m.commute_id
        AND rb.status = 'confirmed'
       JOIN profiles p
         ON p.id = m.sender_id
       WHERE m.recipient_id = $1
         AND m.read_at IS NULL
         AND (
           (
             c.driver_id = $1
             AND rb.passenger_id = m.sender_id
           )
           OR
           (
             rb.passenger_id = $1
             AND c.driver_id = m.sender_id
           )
         )
       GROUP BY
         m.commute_id,
         m.sender_id,
         p.display_name
       ORDER BY latest_message_at DESC`,
      [currentUserId],
    );

    const totalUnread = result.rows.reduce(
      (total, row) => total + Number(row.unread_count || 0),
      0,
    );

    res.json({
      total_unread: totalUnread,
      conversations: result.rows,
    });
  } catch (error) {
    console.error('Get unread chat messages error:', error);
    res.status(500).json({
      error: 'Failed to load unread chat messages.',
    });
  }
});
/*
 * Get private conversation between the current user
 * and one specific driver/passenger.
 */
router.get('/:commuteId/:participantId', requireAuth, async (req, res) => {
  try {
    const { commuteId, participantId } = req.params;
    const currentUserId = req.user.id;

    const access = await getChatAccess(
      commuteId,
      currentUserId,
      participantId,
    );

    if (!access) {
      return res.status(403).json({
        error: 'You are not allowed to chat with this person.',
      });
    }

    const result = await query(
      `SELECT
         m.id,
         m.commute_id,
         m.sender_id,
         m.recipient_id,
         m.body,
         m.created_at,
         m.read_at,
         p.display_name AS sender_name
       FROM chat_messages m
       JOIN profiles p ON p.id = m.sender_id
       WHERE m.commute_id = $1
         AND (
           (m.sender_id = $2 AND m.recipient_id = $3)
           OR
           (m.sender_id = $3 AND m.recipient_id = $2)
         )
       ORDER BY m.created_at ASC
       LIMIT 200`,
      [commuteId, currentUserId, participantId],
    );

    res.json({ messages: result.rows });
  } catch (error) {
    console.error('Get chat messages error:', error);
    res.status(500).json({
      error: 'Failed to load chat messages.',
    });
  }
});

/*
 * Send a private message to one specific driver/passenger.
 */
router.post('/:commuteId/:participantId', requireAuth, async (req, res) => {
  try {
    const { commuteId, participantId } = req.params;
    const currentUserId = req.user.id;
    const { body } = req.body;

    if (!body?.trim()) {
      return res.status(400).json({
        error: 'Message body required',
      });
    }

    if (participantId === currentUserId) {
      return res.status(400).json({
        error: 'You cannot message yourself.',
      });
    }

    const access = await getChatAccess(
      commuteId,
      currentUserId,
      participantId,
    );

    if (!access) {
      return res.status(403).json({
        error: 'You are not allowed to chat with this person.',
      });
    }

    const result = await query(
      `INSERT INTO chat_messages (
         commute_id,
         sender_id,
         recipient_id,
         body
       )
       VALUES ($1, $2, $3, $4)
       RETURNING
         id,
         commute_id,
         sender_id,
         recipient_id,
         body,
         created_at,
         read_at`,
      [
        commuteId,
        currentUserId,
        participantId,
        body.trim(),
      ],
    );

    res.status(201).json({
      message: result.rows[0],
    });
  } catch (error) {
    console.error('Send chat message error:', error);
    res.status(500).json({
      error: 'Failed to send chat message.',
    });
  }
});

/*
 * Mark the private conversation as read.
 */
router.patch(
  '/:commuteId/:participantId/read',
  requireAuth,
  async (req, res) => {
    try {
      const { commuteId, participantId } = req.params;
      const currentUserId = req.user.id;

      const access = await getChatAccess(
        commuteId,
        currentUserId,
        participantId,
      );

      if (!access) {
        return res.status(403).json({
          error: 'You are not allowed to access this chat.',
        });
      }

      const result = await query(
        `UPDATE chat_messages
         SET read_at = NOW()
         WHERE commute_id = $1
           AND sender_id = $2
           AND recipient_id = $3
           AND read_at IS NULL
         RETURNING id`,
        [
          commuteId,
          participantId,
          currentUserId,
        ],
      );

      res.json({
        marked_read: result.rowCount,
      });
    } catch (error) {
      console.error('Mark chat read error:', error);
      res.status(500).json({
        error: 'Failed to mark messages as read.',
      });
    }
  },
);

export default router;