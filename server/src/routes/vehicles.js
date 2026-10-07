import { Router } from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

/*
 * Check whether the current user is an approved driver.
 */
async function requireVerifiedDriver(req, res, next) {
    const result = await query(
        `
        SELECT verification_status
        FROM driver_details
        WHERE user_id = $1
        `,
        [req.user.id],
    );

    if (result.rows[0]?.verification_status !== 'approved') {
        return res.status(403).json({
            error: 'Driver verification required',
            code: 'DRIVER_VERIFICATION_REQUIRED',
        });
    }

    next();
}

/*
 * GET /vehicles
 * Get all vehicles belonging to the current user.
 */
router.get('/', requireAuth, requireVerifiedDriver, async (req, res) => {
    const result = await query(
        `
        SELECT
            id,
            user_id,
            vehicle_type,
            vehicle_name,
            vehicle_number,
            vehicle_color,
            created_at,
            updated_at
        FROM vehicles
        WHERE user_id = $1
        ORDER BY created_at ASC
        `,
        [req.user.id],
    );

    res.json({
        vehicles: result.rows,
    });
});

/*
 * POST /vehicles
 * Add a new vehicle.
 */
router.post('/', requireAuth, requireVerifiedDriver, async (req, res) => {
    const {
        vehicle_type,
        vehicle_name,
        vehicle_number,
        vehicle_color,
    } = req.body;

    if (!vehicle_type || !['car', 'bike'].includes(vehicle_type)) {
        return res.status(400).json({
            error: 'Vehicle type must be car or bike',
        });
    }

    if (!vehicle_name?.trim()) {
        return res.status(400).json({
            error: 'Vehicle name is required',
        });
    }

    if (!vehicle_number?.trim()) {
        return res.status(400).json({
            error: 'Vehicle number is required',
        });
    }

    try {
        const result = await query(
            `
            INSERT INTO vehicles (
                user_id,
                vehicle_type,
                vehicle_name,
                vehicle_number,
                vehicle_color
            )
            VALUES ($1, $2, $3, $4, $5)
            RETURNING
                id,
                user_id,
                vehicle_type,
                vehicle_name,
                vehicle_number,
                vehicle_color,
                created_at,
                updated_at
            `,
            [
                req.user.id,
                vehicle_type,
                vehicle_name.trim(),
                vehicle_number.trim(),
                vehicle_color?.trim() || null,
            ],
        );

        res.status(201).json({
            vehicle: result.rows[0],
        });
    } catch (error) {
        if (error.code === '23505') {
            return res.status(409).json({
                error: 'Vehicle number already exists',
                code: 'VEHICLE_NUMBER_EXISTS',
            });
        }

        throw error;
    }
});

/*
 * PATCH /vehicles/:id
 * Update an existing vehicle belonging to the current user.
 */
router.patch('/:id', requireAuth, requireVerifiedDriver, async (req, res) => {
    const {
        vehicle_type,
        vehicle_name,
        vehicle_number,
        vehicle_color,
    } = req.body;

    if (
        vehicle_type !== undefined &&
        !['car', 'bike'].includes(vehicle_type)
    ) {
        return res.status(400).json({
            error: 'Vehicle type must be car or bike',
        });
    }

    if (vehicle_name !== undefined && !vehicle_name.trim()) {
        return res.status(400).json({
            error: 'Vehicle name cannot be empty',
        });
    }

    if (vehicle_number !== undefined && !vehicle_number.trim()) {
        return res.status(400).json({
            error: 'Vehicle number cannot be empty',
        });
    }

    // A vehicle can be edited after historical rides, because each commute
    // stores its own vehicle snapshot. However, do not allow changes while
    // the vehicle is attached to a currently active ride.
    const activeRideResult = await query(
        `
        SELECT c.id
        FROM commutes c
        JOIN vehicles v ON v.id = c.vehicle_id
        WHERE c.vehicle_id = $1
          AND v.user_id = $2
          AND c.status IN ('open', 'full', 'started')
        LIMIT 1
        `,
        [req.params.id, req.user.id],
    );

    if (activeRideResult.rows[0]) {
        return res.status(409).json({
            error: 'This vehicle is currently being used for an active ride',
            code: 'VEHICLE_IN_USE',
        });
    }

    try {
        const result = await query(
            `
            UPDATE vehicles
            SET
                vehicle_type = COALESCE($1, vehicle_type),
                vehicle_name = COALESCE($2, vehicle_name),
                vehicle_number = COALESCE($3, vehicle_number),
                vehicle_color = COALESCE($4, vehicle_color),
                updated_at = NOW()
            WHERE id = $5
              AND user_id = $6
            RETURNING
                id,
                user_id,
                vehicle_type,
                vehicle_name,
                vehicle_number,
                vehicle_color,
                created_at,
                updated_at
            `,
            [
                vehicle_type ?? null,
                vehicle_name !== undefined ? vehicle_name.trim() : null,
                vehicle_number !== undefined ? vehicle_number.trim() : null,
                vehicle_color !== undefined
                    ? (vehicle_color?.trim() || null)
                    : null,
                req.params.id,
                req.user.id,
            ],
        );

        if (!result.rows[0]) {
            return res.status(404).json({
                error: 'Vehicle not found',
            });
        }

        res.json({
            vehicle: result.rows[0],
        });
    } catch (error) {
        if (error.code === '23505') {
            return res.status(409).json({
                error: 'Vehicle number already exists',
                code: 'VEHICLE_NUMBER_EXISTS',
            });
        }

        throw error;
    }
});

/*
 * DELETE /vehicles/:id
 * Delete a vehicle belonging to the current user.
 *
 * Historical rides are safe because commutes store their own vehicle
 * snapshot. A vehicle can be deleted after its historical rides are over,
 * but it cannot be deleted while it is being used by an active ride.
 */
router.delete('/:id', requireAuth, requireVerifiedDriver, async (req, res) => {
    const activeRideResult = await query(
        `
        SELECT c.id
        FROM commutes c
        JOIN vehicles v ON v.id = c.vehicle_id
        WHERE c.vehicle_id = $1
          AND v.user_id = $2
          AND c.status IN ('open', 'full', 'started')
        LIMIT 1
        `,
        [req.params.id, req.user.id],
    );

    if (activeRideResult.rows[0]) {
        return res.status(409).json({
            error: 'This vehicle is currently being used for an active ride',
            code: 'VEHICLE_IN_USE',
        });
    }

    const result = await query(
        `
        DELETE FROM vehicles
        WHERE id = $1
          AND user_id = $2
        RETURNING id
        `,
        [req.params.id, req.user.id],
    );

    if (!result.rows[0]) {
        return res.status(404).json({
            error: 'Vehicle not found',
        });
    }

    res.json({
        success: true,
    });
});

export default router;