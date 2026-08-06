import { query } from '../../db/pool.js';
/**
 * Records an Operations audit log.
 */
export async function logOperation({
    adminProfileId,
    targetProfileId = null,
    action,
    entityType,
    entityId = null,
    reason = null,
    status = 'SUCCESS',
    req = null,
    client = null,
}) {
    const ipAddress =
        req?.headers['x-forwarded-for'] ||
        req?.socket?.remoteAddress ||
        null;

    const userAgent =
        req?.headers['user-agent'] || null;

    const executor = client ?? { query };

    await executor.query(
        `
      INSERT INTO operations_audit_logs
      (
        admin_profile_id,
        target_profile_id,
        action,
        entity_type,
        entity_id,
        reason,
        status,
        ip_address,
        user_agent
      )
      VALUES
      (
        $1,$2,$3,$4,$5,$6,$7,$8,$9
      )
    `,
        [
            adminProfileId,
            targetProfileId,
            action,
            entityType,
            entityId,
            reason,
            status,
            ipAddress,
            userAgent,
        ]
    );
}