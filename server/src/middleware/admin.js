import { query } from '../db/pool.js';

export async function requireAdmin(req, res, next) {
    try {
        const result = await query(
            `
      SELECT role
      FROM profiles
      WHERE id = $1
      `,
            [req.user.id]
        );

        if (result.rowCount === 0) {
            return res.status(403).json({
                error: 'Profile not found',
            });
        }

        const role = result.rows[0].role;
        req.userRole = role;

        if (role !== 'admin') {
            return res.status(403).json({
                error: 'Administrator access required',
            });
        }

        next();
    } catch (err) {
        console.error(err);

        return res.status(500).json({
            error: 'Failed to verify administrator',
        });
    }
}