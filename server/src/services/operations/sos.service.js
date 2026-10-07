import { query } from '../../db/pool.js';

export async function getSosAlerts({
    page = 1,
    limit = 20,
    status = 'active',
} = {}) {
    const safePage = Math.max(1, Number(page) || 1);
    const safeLimit = Math.min(100, Math.max(1, Number(limit) || 20));
    const offset = (safePage - 1) * safeLimit;

    const values = [];
    let where = '';

    if (status === 'active' || status === 'resolved' || status === 'cancelled') {
        values.push(status);
        where = `WHERE s.status = $${values.length}`;
    } else if (status === 'all') {
        where = '';
    } else {
        throw new Error('INVALID_SOS_STATUS');
    }

    const count = await query(
        `SELECT COUNT(*)::int AS count
         FROM sos_alerts s
         ${where}`,
        values,
    );

    const listValues = [...values, safeLimit, offset];

    const result = await query(
        `SELECT
            s.id,
            s.trip_safety_session_id,
            s.commute_id,
            s.user_id,
            s.status,
            s.latitude,
            s.longitude,
            s.message,
            s.created_at,
            s.resolved_at,

            p.full_name AS user_name,
            p.display_name AS user_display_name,
            p.email AS user_email,
            p.phone_number AS user_phone,

            c.driver_id,
            c.from_address,
            c.to_address,
            c.from_lat,
            c.from_lng,
            c.to_lat,
            c.to_lng,
            c.departure_at,
            c.status AS commute_status

         FROM sos_alerts s

         JOIN profiles p
           ON p.id = s.user_id

         JOIN commutes c
           ON c.id = s.commute_id

         ${where}

         ORDER BY
            CASE WHEN s.status = 'active' THEN 0 ELSE 1 END,
            s.created_at DESC

         LIMIT $${listValues.length - 1}
         OFFSET $${listValues.length}`,
        listValues,
    );

    return {
        items: result.rows,
        page: safePage,
        limit: safeLimit,
        total: count.rows[0].count,
        totalPages: Math.ceil(count.rows[0].count / safeLimit),
    };
}

export async function getSosAlert(alertId) {
    const result = await query(
        `SELECT
            s.id,
            s.trip_safety_session_id,
            s.commute_id,
            s.user_id,
            s.status,
            s.latitude,
            s.longitude,
            s.message,
            s.created_at,
            s.resolved_at,

            p.full_name AS user_name,
            p.display_name AS user_display_name,
            p.email AS user_email,
            p.phone_number AS user_phone,

            c.driver_id,
            c.from_address,
            c.to_address,
            c.from_lat,
            c.from_lng,
            c.to_lat,
            c.to_lng,
            c.departure_at,
            c.status AS commute_status,

            tss.started_at,
            tss.ended_at,
            tss.expires_at,
            tss.latest_latitude,
            tss.latest_longitude,
            tss.last_location_update_at

         FROM sos_alerts s

         JOIN profiles p
           ON p.id = s.user_id

         JOIN commutes c
           ON c.id = s.commute_id

         LEFT JOIN trip_safety_sessions tss
           ON tss.id = s.trip_safety_session_id

         WHERE s.id = $1

         LIMIT 1`,
        [alertId],
    );

    if (result.rowCount === 0) {
        return null;
    }

    return result.rows[0];
}

export async function resolveSosAlert({
    alertId,
    adminProfileId,
    req,
    logOperation,
}) {
    const result = await query(
        `UPDATE sos_alerts
         SET
            status = 'resolved',
            resolved_at = NOW()
         WHERE id = $1
           AND status = 'active'
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
        [alertId],
    );

    if (result.rowCount === 0) {
        const existing = await query(
            `SELECT id, status
             FROM sos_alerts
             WHERE id = $1
             LIMIT 1`,
            [alertId],
        );

        if (existing.rowCount === 0) {
            return null;
        }

        throw new Error('SOS_ALREADY_RESOLVED');
    }

    if (logOperation) {
        try {
            await logOperation({
                adminProfileId,
                action: 'sos_alert_resolved',
                entityType: 'sos_alert',
                entityId: alertId,
                targetProfileId: result.rows[0].user_id,
                req,
            });
        } catch (auditError) {
            console.error(
                'SOS alert resolved, but audit logging failed:',
                auditError,
            );
        }
    }

    return result.rows[0];
}