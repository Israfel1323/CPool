import { query } from '../../db/pool.js';

/**
 * Returns Operations audit logs.
 */
export async function getAuditLogs({
    page = 1,
    limit = 20,
}) {

    const offset = (page - 1) * limit;

    const result = await query(
        `
        SELECT
            o.id,
            o.action,
            o.entity_type,
            o.entity_id,
            o.reason,
            o.status,
            o.ip_address,
            o.user_agent,
            o.created_at,

            admin.full_name AS admin_name,
            target.full_name AS target_name,
            target.email AS target_email

        FROM operations_audit_logs o

        LEFT JOIN profiles admin
        ON admin.id = o.admin_profile_id

        LEFT JOIN profiles target
        ON target.id = o.target_profile_id

        ORDER BY o.created_at DESC

        LIMIT $1
        OFFSET $2
        `,
        [limit, offset]
    );

    return result.rows;
}