import { query, getPool } from '../../db/pool.js';

/**
 * Get verification requests with filters & pagination.
 */
export async function getVerificationRequests({
  status = 'pending',
  type = null,
  search = '',
  page = 1,
  limit = 20,
}) {
  const offset = (page - 1) * limit;

  const values = [];
  const conditions = [];

  if (status) {
    values.push(status);
    conditions.push(`vr.status = $${values.length}`);
  }

  if (search) {
    values.push(`%${search}%`);

    conditions.push(`
    (
      p.full_name ILIKE $${values.length}
      OR p.email ILIKE $${values.length}
      OR EXISTS (
        SELECT 1
        FROM driver_details d
        WHERE d.user_id = vr.profile_id
        AND (
          d.vehicle_name ILIKE $${values.length}
          OR d.vehicle_number ILIKE $${values.length}
        )
      )
    )
  `);
  }

  values.push(limit);
  const limitIndex = values.length;

  values.push(offset);
  const offsetIndex = values.length;

  const whereClause =
    conditions.length > 0
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

  const result = await query(
    `
      SELECT

        vr.id,

        vr.verification_type,

        vr.status,

        vr.created_at,

        p.id AS profile_id,

        p.full_name,

        p.email

      FROM verification_requests vr

      JOIN profiles p
      ON p.id = vr.profile_id

      ${whereClause}

      ORDER BY vr.created_at DESC

      LIMIT $${limitIndex}

      OFFSET $${offsetIndex}
    `,
    values
  );
  const filterValues = values.slice(0, limitIndex - 1);

  const countResult = await query(
    `
    SELECT COUNT(*)::int AS total
    FROM verification_requests vr
    JOIN profiles p
      ON p.id = vr.profile_id
    ${whereClause}
  `,
    filterValues
  );
  const totalItems = countResult.rows[0].total;

  const totalPages = Math.max(
    1,
    Math.ceil(totalItems / limit)
  );

  return {
    items: result.rows,

    pagination: {
      page,
      limit,
      totalItems,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1,
    },
  };
}
/**
 * Get a single verification request.
 */
export async function getVerificationRequest(id) {

  const result = await query(
    `
    SELECT

      vr.*,

      p.full_name,

      p.email,

      d.vehicle_type,

      d.vehicle_name,

      d.vehicle_number,

      d.vehicle_color,

      d.license_front_url,

      d.license_back_url

    FROM verification_requests vr

    JOIN profiles p
      ON p.id = vr.profile_id

    LEFT JOIN driver_details d
      ON d.user_id = vr.profile_id

    WHERE vr.id = $1
    `,
    [id]
  );

  return result.rows[0] ?? null;
}
/**
 * Update verification request status.
 */
export async function updateVerificationStatus({
  verificationId,
  status,
  reason = null,
  adminProfileId,
}) {

  const result = await query(
    `
      UPDATE verification_requests
      SET
        status = $2,
        reviewed_by = $3,
        reviewed_at = NOW(),
        rejection_reason = $4,
        updated_at = NOW()
      WHERE id = $1
      RETURNING *;
    `,
    [
      verificationId,
      status,
      adminProfileId,
      reason,
    ]
  );

  return result.rows[0] ?? null;
}
export async function updateVerificationStatusWithAudit({
  verificationId,
  status,
  reason = null,
  adminProfileId,
  req,
  logOperation,
}) {
  const client = await getPool().connect();

  try {
    await client.query('BEGIN');

    const updateResult = await client.query(
      `
      UPDATE verification_requests
      SET
        status = $2,
        reviewed_by = $3,
        reviewed_at = NOW(),
        rejection_reason = $4,
        updated_at = NOW()
      WHERE id = $1
      RETURNING *;
      `,
      [
        verificationId,
        status,
        adminProfileId,
        reason,
      ]
    );

    const verification = updateResult.rows[0];

    if (!verification) {
      throw new Error('Verification request not found.');
    }

    await logOperation({
      adminProfileId,
      targetProfileId: verification.profile_id,
      action:
        status === 'approved'
          ? 'APPROVE_VERIFICATION'
          : 'REJECT_VERIFICATION',
      entityType: verification.verification_type,
      entityId: verification.id,
      reason,
      status: 'SUCCESS',
      req,
      client,
    });

    await client.query('COMMIT');

    return verification;

  } catch (err) {

    await client.query('ROLLBACK');

    throw err;

  } finally {

    client.release();

  }
}