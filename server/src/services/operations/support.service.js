import { query } from '../../db/pool.js';

export async function getSupportTickets({ page = 1, limit = 20, status = 'open', search = '' } = {}) {
    const safePage = Math.max(1, Number(page) || 1);
    const safeLimit = Math.min(100, Math.max(1, Number(limit) || 20));
    const offset = (safePage - 1) * safeLimit;

    const values = [];
    const conditions = [];

    if (status === 'open' || status === 'resolved') {
        values.push(status);
        conditions.push(`t.status = $${values.length}`);
    } else if (status !== 'all') {
        throw new Error('INVALID_SUPPORT_STATUS');
    }

    if (search) {
        values.push(`%${search}%`);
        conditions.push(`(
            t.description ILIKE $${values.length}
            OR t.category ILIKE $${values.length}
            OR p.full_name ILIKE $${values.length}
            OR p.email ILIKE $${values.length}
        )`);
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const count = await query(
        `SELECT COUNT(*)::int AS count
         FROM support_tickets t
         JOIN profiles p ON p.id = t.user_id
         ${where}`,
        values,
    );

    const listValues = [...values, safeLimit, offset];

    const result = await query(
        `SELECT t.id, t.user_id, t.commute_id, t.category, t.description,
                t.status, t.created_at, t.updated_at, t.resolved_at,
                p.full_name AS user_name, p.email AS user_email
         FROM support_tickets t
         JOIN profiles p ON p.id = t.user_id
         ${where}
         ORDER BY CASE WHEN t.status = 'open' THEN 0 ELSE 1 END,
                  t.created_at DESC
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

export async function getSupportTicket(ticketId) {
    const ticket = await query(
        `SELECT t.id, t.user_id, t.commute_id, t.category, t.description,
                t.status, t.created_at, t.updated_at, t.resolved_at,
                p.full_name AS user_name, p.email AS user_email
         FROM support_tickets t
         JOIN profiles p ON p.id = t.user_id
         WHERE t.id = $1 LIMIT 1`,
        [ticketId],
    );

    if (ticket.rowCount === 0) return null;

    const messages = await query(
        `SELECT m.id, m.sender_id, m.sender_role, m.message, m.created_at,
                p.full_name AS sender_name, p.email AS sender_email
         FROM support_messages m
         JOIN profiles p ON p.id = m.sender_id
         WHERE m.ticket_id = $1
         ORDER BY m.created_at ASC`,
        [ticketId],
    );

    return { ticket: ticket.rows[0], messages: messages.rows };
}

export async function replyToSupportTicket({ ticketId, adminProfileId, message }) {
    const cleanMessage = message?.trim();
    if (!cleanMessage) throw new Error('MESSAGE_REQUIRED');

    const ticket = await query(
        `SELECT id, status FROM support_tickets WHERE id = $1 LIMIT 1`,
        [ticketId],
    );

    if (ticket.rowCount === 0) return null;
    if (ticket.rows[0].status === 'resolved') throw new Error('TICKET_RESOLVED');

    const result = await query(
        `INSERT INTO support_messages
            (ticket_id, sender_id, sender_role, message)
         VALUES ($1, $2, 'operations', $3)
         RETURNING id, ticket_id, sender_id, sender_role, message, created_at`,
        [ticketId, adminProfileId, cleanMessage],
    );

    return result.rows[0];
}

export async function resolveSupportTicket({ ticketId, adminProfileId, req, logOperation }) {
    const result = await query(
        `UPDATE support_tickets
         SET status = 'resolved', resolved_at = NOW(), updated_at = NOW()
         WHERE id = $1 AND status = 'open'
         RETURNING id, user_id, category, description, status,
                   created_at, updated_at, resolved_at`,
        [ticketId],
    );

    if (result.rowCount === 0) {
        const existing = await query(
            `SELECT id, status FROM support_tickets WHERE id = $1 LIMIT 1`,
            [ticketId],
        );
        if (existing.rowCount === 0) return null;
        throw new Error('TICKET_ALREADY_RESOLVED');
    }

    if (logOperation) {
        try {
            await logOperation({
                adminProfileId,
                action: 'support_ticket_resolved',
                targetType: 'support_ticket',
                targetId: ticketId,
                metadata: { category: result.rows[0].category },
                req,
            });
        } catch (auditError) {
            console.error(
                'Support ticket resolved, but audit logging failed:',
                auditError,
            );
        }
    }

    return result.rows[0];
}
