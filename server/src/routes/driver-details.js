import { Router } from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
router.get('/', requireAuth, async (req, res) => {
    const result = await query(
        `
    SELECT *
    FROM driver_details
    WHERE user_id = $1
    `,
        [req.user.id],
    );

    if (!result.rows[0]) {
        return res.json({
            driverDetails: null,
        });
    }

    res.json({
        driverDetails: result.rows[0],
    });
});
router.put('/', requireAuth, async (req, res) => {
    const {
        vehicle_type,
        vehicle_name,
        vehicle_number,
        vehicle_color,
        license_front_url,
        license_back_url,
    } = req.body;
    console.log('========== DRIVER DETAILS ==========');
    console.log(req.body);
    console.log('====================================');
    if (
        !vehicle_type ||
        !vehicle_name ||
        !vehicle_number ||
        !license_front_url ||
        !license_back_url
    ) {
        return res.status(400).json({
            error: 'Missing required driver details',
        });
    }

    const result = await query(
        `
    INSERT INTO driver_details (
      user_id,
      vehicle_type,
      vehicle_name,
      vehicle_number,
      vehicle_color,
      license_front_url,
      license_back_url,
      verification_status
    )
    VALUES (
      $1,$2,$3,$4,$5,$6,$7,'pending'
    )

    ON CONFLICT (user_id)
    DO UPDATE SET
      vehicle_type = EXCLUDED.vehicle_type,
      vehicle_name = EXCLUDED.vehicle_name,
      vehicle_number = EXCLUDED.vehicle_number,
      vehicle_color = EXCLUDED.vehicle_color,
      license_front_url = EXCLUDED.license_front_url,
      license_back_url = EXCLUDED.license_back_url,
      verification_status = 'pending',
      verified_at = NULL,
      updated_at = NOW()

    RETURNING *;
    `,
        [
            req.user.id,
            vehicle_type,
            vehicle_name,
            vehicle_number,
            vehicle_color ?? null,
            license_front_url,
            license_back_url,
        ],
    );
    await query(
        `
  INSERT INTO verification_requests (
      profile_id,
      institution_name,
      id_card_url,
      verification_type,
      reference_id,
      status
  )
  VALUES (
      $1,
      '',
      '',
      'driver',
      $1,
      'pending'
  )

  ON CONFLICT (profile_id, verification_type)

  DO UPDATE SET
      status = 'pending',
      updated_at = NOW(),
      reviewed_at = NULL,
      reviewed_by = NULL,
      rejection_reason = NULL,
      reference_id = EXCLUDED.reference_id;
  `,
        [req.user.id]
    );
    res.json({
        driverDetails: result.rows[0],
    });
});
export default router;