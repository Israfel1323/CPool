import { Router } from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';
import {
    createEmergencyContactNotifications,
} from '../services/notifications/emergency-contact-notification.service.js';

const router = Router();
router.get('/share/:shareToken', async (req, res) => {
    try {
        const result = await query(
            `SELECT
          tss.id,
          tss.commute_id,
          tss.user_id,
          tss.status,
          tss.share_token,
          tss.started_at,
          tss.ended_at,
          tss.expires_at,
          tss.latest_latitude,
          tss.latest_longitude,
          tss.last_location_update_at,
          c.from_address,
          c.to_address,
          c.departure_at,
          p.display_name
       FROM trip_safety_sessions tss
       JOIN commutes c
         ON c.id = tss.commute_id
       JOIN profiles p
         ON p.id = tss.user_id
       WHERE tss.share_token = $1
       LIMIT 1`,
            [req.params.shareToken],
        );

        const session = result.rows[0];

        if (!session) {
            return res.status(404).json({
                error: 'Trip safety link not found.',
            });
        }

        return res.json({
            session,
        });
    } catch (err) {
        console.error(err);

        return res.status(500).json({
            error: 'Unable to load shared trip.',
        });
    }
});

router.use(requireAuth);

/**
 * Get the current user's safety session for a commute.
 */
router.get('/:commuteId', async (req, res) => {
    try {
        const result = await query(
            `SELECT
          id,
          commute_id,
          user_id,
          status,
          share_token,
          started_at,
          ended_at,
          expires_at,
          latest_latitude,
          latest_longitude,
          last_location_update_at,
          created_at,
          updated_at
       FROM trip_safety_sessions
       WHERE commute_id = $1
         AND user_id = $2
       LIMIT 1`,
            [req.params.commuteId, req.user.id],
        );

        if (!result.rows[0]) {
            return res.status(404).json({
                error: 'Safety session not found',
            });
        }

        return res.json({
            session: result.rows[0],
        });
    } catch (err) {
        console.error(err);

        return res.status(500).json({
            error: 'Unable to fetch safety session.',
        });
    }
});

/**
 * Update the current user's latest location.
 *
 * This will be used later by the live safety/trip-sharing system.
 */
router.patch('/:commuteId/location', async (req, res) => {
    try {
        const latitude = Number(req.body?.latitude);
        const longitude = Number(req.body?.longitude);

        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
            return res.status(400).json({
                error: 'Valid latitude and longitude are required.',
            });
        }

        if (latitude < -90 || latitude > 90) {
            return res.status(400).json({
                error: 'Invalid latitude.',
            });
        }

        if (longitude < -180 || longitude > 180) {
            return res.status(400).json({
                error: 'Invalid longitude.',
            });
        }

        const result = await query(
            `UPDATE trip_safety_sessions
       SET
         latest_latitude = $1,
         latest_longitude = $2,
         last_location_update_at = NOW(),
         updated_at = NOW()
       WHERE commute_id = $3
         AND user_id = $4
         AND status = 'active'
       RETURNING
         id,
         commute_id,
         user_id,
         status,
         latest_latitude,
         latest_longitude,
         last_location_update_at,
         updated_at`,
            [
                latitude,
                longitude,
                req.params.commuteId,
                req.user.id,
            ],
        );

        if (!result.rows[0]) {
            return res.status(404).json({
                error: 'Active safety session not found.',
            });
        }

        return res.json({
            session: result.rows[0],
        });
    } catch (err) {
        console.error(err);

        return res.status(500).json({
            error: 'Unable to update safety location.',
        });
    }
});

/**
 * End the current user's safety session.
 */
router.post('/:commuteId/end', async (req, res) => {
    try {
        const result = await query(
            `UPDATE trip_safety_sessions
       SET
         status = 'completed',
         ended_at = NOW(),
         updated_at = NOW()
       WHERE commute_id = $1
         AND user_id = $2
         AND status = 'active'
       RETURNING *`,
            [
                req.params.commuteId,
                req.user.id,
            ],
        );

        if (!result.rows[0]) {
            return res.status(404).json({
                error: 'Active safety session not found.',
            });
        }

        return res.json({
            session: result.rows[0],
            status: 'completed',
        });
    } catch (err) {
        console.error(err);

        return res.status(500).json({
            error: 'Unable to end safety session.',
        });
    }
});
/**
 * Trigger an SOS alert for the current user's active trip.
 */
router.post('/:commuteId/sos', async (req, res) => {
    try {
        const message =
            typeof req.body?.message === 'string'
                ? req.body.message.trim()
                : null;

        const sessionResult = await query(
            `SELECT
  tss.id,
  tss.commute_id,
  tss.user_id,
  tss.status,
  tss.latest_latitude,
  tss.latest_longitude,
  tss.share_token,
  p.display_name AS user_name,
  c.from_address,
  c.to_address
FROM trip_safety_sessions tss
JOIN profiles p
  ON p.id = tss.user_id
JOIN commutes c
  ON c.id = tss.commute_id
WHERE tss.commute_id = $1
  AND tss.user_id = $2
  AND tss.status = 'active'
LIMIT 1`,
            [
                req.params.commuteId,
                req.user.id,
            ],
        );

        const session = sessionResult.rows[0];

        if (!session) {
            return res.status(404).json({
                error: 'Active trip safety session not found.',
            });
        }

        const existingResult = await query(
            `SELECT id
       FROM sos_alerts
       WHERE trip_safety_session_id = $1
         AND status = 'active'
       LIMIT 1`,
            [session.id],
        );

        if (existingResult.rows[0]) {
            return res.status(409).json({
                error: 'An SOS alert is already active for this trip.',
                alert_id: existingResult.rows[0].id,
            });
        }

        const result = await query(
            `INSERT INTO sos_alerts
          (
            trip_safety_session_id,
            commute_id,
            user_id,
            status,
            latitude,
            longitude,
            message
          )
       VALUES ($1, $2, $3, 'active', $4, $5, $6)
       RETURNING
         id,
         trip_safety_session_id,
         commute_id,
         user_id,
         status,
         latitude,
         longitude,
         message,
         created_at,
         resolved_at`,
            [
                session.id,
                session.commute_id,
                session.user_id,
                session.latest_latitude,
                session.latest_longitude,
                message || null,
            ],
        );
        try {
            await createEmergencyContactNotifications({
                sosAlertId: result.rows[0].id,
                userId: session.user_id,
                userName: session.user_name,
                fromAddress: session.from_address,
                toAddress: session.to_address,
                latitude: session.latest_latitude,
                longitude: session.latest_longitude,
                message,
                shareToken: session.share_token,
            });
        } catch (notificationError) {
            console.error(
                'Emergency contact notification creation failed:',
                notificationError,
            );
        }
        return res.status(201).json({
            alert: result.rows[0],
            status: 'active',
        });
    } catch (err) {
        console.error(err);

        return res.status(500).json({
            error: 'Unable to trigger SOS alert.',
        });
    }
});
export default router;