import { query } from '../../db/pool.js';

/**
 * Returns dashboard summary statistics.
 */
export async function getDashboardSummary() {
    const result = await query(`
        SELECT
            COUNT(*) FILTER (WHERE status = 'pending')::INT  AS pending_verifications,
            COUNT(*) FILTER (WHERE status = 'approved')::INT AS approved_verifications,
            COUNT(*) FILTER (WHERE status = 'rejected')::INT AS rejected_verifications,

            COUNT(*) FILTER (
                WHERE status = 'pending'
                AND verification_type = 'driver'
            )::INT AS pending_drivers,

            COUNT(*) FILTER (
                WHERE status = 'pending'
                AND verification_type = 'student'
            )::INT AS pending_students
        FROM verification_requests
    `);

    return result.rows[0];
}