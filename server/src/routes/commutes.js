import { Router } from 'express';
import { getPool, query } from '../db/pool.js';
import { optionalAuth, requireAuth } from '../middleware/auth.js';

const router = Router();

router.get('/', optionalAuth, async (req, res) => {
  const {
    from_lat,
    from_lng,
    to_lat,
    to_lng,
    pool_type,
    women_only,
    departure_at,
  } = req.query;

  let sql = `
    SELECT
  c.*,
  p.display_name AS driver_name,
  p.institution_name AS driver_institution,
  p.driver_verified,
  (
    SELECT ROUND(AVG(r.score)::numeric, 1)
    FROM ratings r
    WHERE r.rated_id = c.driver_id
  ) AS driver_rating,
  (
    SELECT COUNT(*)::int
    FROM ratings r
    WHERE r.rated_id = c.driver_id
  ) AS driver_rating_count,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'id', i.id,
          'name', i.name,
          'category', i.category,
          'icon', i.icon,
          'display_order', i.display_order
        )
        ORDER BY i.display_order ASC, i.name ASC
      )
      FROM profile_interests pi
      JOIN interests i ON i.id = pi.interest_id
      WHERE pi.profile_id = c.driver_id
    ),
    '[]'::json
  ) AS driver_interests,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'id', i.id,
          'name', i.name,
          'category', i.category,
          'icon', i.icon,
          'display_order', i.display_order
        )
        ORDER BY i.display_order ASC, i.name ASC
      )
      FROM profile_interests pi
      JOIN interests i ON i.id = pi.interest_id
      JOIN profile_interests my_pi
        ON my_pi.interest_id = pi.interest_id
       AND my_pi.profile_id = $1
      WHERE pi.profile_id = c.driver_id
        AND $1::uuid IS NOT NULL
    ),
    '[]'::json
  ) AS common_interests
FROM commutes c
JOIN profiles p ON p.id = c.driver_id
WHERE c.status = 'open' AND c.departure_at > NOW() AND c.seats_available > 0
  AND c.vehicle_id IS NOT NULL`;

  // Keep the authenticated user as $1 for common-interest matching.
  // When unauthenticated, $1 is NULL and common_interests becomes [].
  const params = [req.user?.id ?? null];

  if (req.user) {
    sql += ` AND c.driver_id <> $1`;
  }

  if (pool_type) {
    params.push(pool_type);
    sql += ` AND c.pool_type = $${params.length}`;
  }

  if (women_only === 'true') {
    sql += ` AND c.women_only = TRUE`;
  } else {
    sql += ` AND c.women_only = FALSE`;
  }

  if (
    from_lat &&
    from_lng &&
    to_lat &&
    to_lng
  ) {
    params.push(Number(from_lat));
    params.push(Number(from_lng));
    params.push(Number(to_lat));
    params.push(Number(to_lng));

    const fromLatIndex = params.length - 3;
    const fromLngIndex = params.length - 2;
    const toLatIndex = params.length - 1;
    const toLngIndex = params.length;

    sql += `
    AND ABS(c.from_lat - $${fromLatIndex}) < 0.05
    AND ABS(c.from_lng - $${fromLngIndex}) < 0.05
    AND ABS(c.to_lat - $${toLatIndex}) < 0.05
    AND ABS(c.to_lng - $${toLngIndex}) < 0.05
  `;
  }
  if (departure_at) {
    const requestedDeparture = new Date(departure_at);

    if (Number.isNaN(requestedDeparture.getTime())) {
      return res.status(400).json({
        error: 'Invalid departure time.',
      });
    }

    params.push(requestedDeparture);
    const departureIndex = params.length;

    sql += `
      AND c.departure_at BETWEEN
        $${departureIndex}::timestamptz - INTERVAL '30 minutes'
        AND
        $${departureIndex}::timestamptz + INTERVAL '30 minutes'
    `;

    sql += `
      ORDER BY ABS(
        EXTRACT(
          EPOCH FROM (c.departure_at - $${departureIndex}::timestamptz)
        )
      ) ASC
    `;

    sql += ' LIMIT 50';
  } else {
    sql += ' ORDER BY c.departure_at ASC LIMIT 50';
  }

  const result = await query(sql, params);

  let bookedRideIds = [];

  if (req.user) {
    const bookings = await query(
      `SELECT commute_id
       FROM ride_bookings
       WHERE passenger_id = $1
  AND status IN ('pending', 'confirmed', 'boarded')`,
      [req.user.id],
    );

    bookedRideIds = bookings.rows.map(
      (b) => b.commute_id,
    );
  }

  const commutes = result.rows.map((ride) => ({
    ...ride,
    already_booked: bookedRideIds.includes(
      ride.id,
    ),
  }));

  res.json({
    commutes,
    search: {
      from_lat,
      from_lng,
      to_lat,
      to_lng,
    },
  });
});

router.post('/', requireAuth, async (req, res) => {
  const {
    from_address,
    to_address,
    from_lat,
    from_lng,
    to_lat,
    to_lng,
    pool_type = 'carpool',
    women_only = false,
    seats_total = 3,
    cost_per_seat_paise = 0,
    departure_at,
    notes,
    vehicle_id,
  } = req.body;
  if (!vehicle_id) {
    return res.status(400).json({
      error: 'Vehicle is required',
      code: 'VEHICLE_REQUIRED',
    });
  }

  if (!from_address || !to_address || departure_at == null) {
    return res.status(400).json({
      error: 'Missing required commute fields',
    });
  }
  const vehicleResult = await query(
    `SELECT
       id,
       vehicle_type,
       vehicle_name,
       vehicle_number,
       vehicle_color
     FROM vehicles
     WHERE id = $1
       AND user_id = $2`,
    [vehicle_id, req.user.id],
  );

  if (!vehicleResult.rows[0]) {
    return res.status(403).json({
      error: 'Vehicle does not belong to this driver',
      code: 'VEHICLE_NOT_OWNED',
    });
  }
  const expectedVehicleType =
    pool_type === 'bikepool' ? 'bike' : 'car';

  if (vehicleResult.rows[0].vehicle_type !== expectedVehicleType) {
    return res.status(400).json({
      error: 'Selected vehicle does not match the pool type',
      code: 'VEHICLE_TYPE_MISMATCH',
    });
  }
  await query(
    `INSERT INTO profiles (id, email, display_name)
     VALUES ($1, $2, $3)
     ON CONFLICT (id) DO NOTHING`,
    [
      req.user.id,
      req.user.email,
      req.user.email?.split('@')[0],
    ],
  );

  const result = await query(
    `INSERT INTO commutes (
      driver_id,
      from_address,
      to_address,
      from_lat,
      from_lng,
      to_lat,
      to_lng,
      pool_type,
      women_only,
      seats_total,
      seats_available,
      cost_per_seat_paise,
      departure_at,
      notes,
      vehicle_id,
      vehicle_type,
      vehicle_name,
      vehicle_number,
      vehicle_color
    )
    VALUES (
      $1, $2, $3, $4, $5, $6, $7,
      $8, $9, $10, $10, $11, $12, $13, $14,
      $15, $16, $17, $18
    )
    RETURNING *`,
    [
      req.user.id,
      from_address,
      to_address,
      from_lat,
      from_lng,
      to_lat,
      to_lng,
      pool_type,
      women_only,
      seats_total,
      cost_per_seat_paise,
      departure_at,
      notes,
      vehicle_id,
      vehicleResult.rows[0].vehicle_type,
      vehicleResult.rows[0].vehicle_name,
      vehicleResult.rows[0].vehicle_number,
      vehicleResult.rows[0].vehicle_color,
    ]
  );

  res.status(201).json({
    commute: result.rows[0],
  });
});

router.get('/mine', requireAuth, async (req, res) => {
  const result = await query(
    `SELECT c.*, p.display_name AS driver_name,
p.institution_name AS driver_institution
     FROM commutes c
     JOIN profiles p ON p.id = c.driver_id
     WHERE c.driver_id = $1
AND c.status NOT IN (
  'completed',
  'cancelled'
)
     ORDER BY c.departure_at DESC`,
    [req.user.id],
  );

  res.json({
    commutes: result.rows,
  });
});

router.get('/booked', requireAuth, async (req, res) => {
  const result = await query(
    `SELECT
        c.*,
        p.display_name AS driver_name,
p.institution_name AS driver_institution,
        (
          SELECT ROUND(AVG(r.score)::numeric, 1)
          FROM ratings r
          WHERE r.rated_id = c.driver_id
        ) AS driver_rating,
        (
          SELECT COUNT(*)::int
          FROM ratings r
          WHERE r.rated_id = c.driver_id
        ) AS driver_rating_count,
        rb.status AS booking_status
     FROM ride_bookings rb
     JOIN commutes c
       ON c.id = rb.commute_id
     JOIN profiles p
       ON p.id = c.driver_id
     WHERE rb.passenger_id = $1
     ORDER BY c.departure_at DESC`,
    [req.user.id],
  );

  res.json({
    commutes: result.rows,
  });
});

router.get('/history', requireAuth, async (req, res) => {
  const result = await query(
    `
    SELECT
      c.*,
      p.display_name AS driver_name,
      p.institution_name AS driver_institution,
      CASE
        WHEN c.driver_id = $1 THEN 'driver'
        ELSE 'passenger'
      END AS my_role,
      COALESCE(
        (
          SELECT json_agg(
            json_build_object(
              'booking_id', rb.id,
              'passenger_id', rb.passenger_id,
              'passenger_name', pp.display_name,
              'passenger_institution', pp.institution_name,
              'travelling_mode', rb.travelling_mode,
              'travelling_passenger_name', rb.travelling_passenger_name,
              'travelling_passenger_gender', rb.travelling_passenger_gender,
              'seats', rb.seats,
              'booking_status', rb.status,
              'guests', COALESCE(
                (
                  SELECT json_agg(
                    json_build_object(
                      'id', bg.id,
                      'name', bg.name,
                      'gender', bg.gender
                    )
                    ORDER BY bg.created_at ASC
                  )
                  FROM booking_guests bg
                  WHERE bg.booking_id = rb.id
                ),
                '[]'::json
              )
            )
            ORDER BY rb.created_at ASC
          )
          FROM ride_bookings rb
          JOIN profiles pp
            ON pp.id = rb.passenger_id
          WHERE rb.commute_id = c.id
            AND (
              c.driver_id = $1
              OR rb.passenger_id = $1
            )
            AND rb.status IN ('confirmed', 'boarded', 'completed')
        ),
        '[]'::json
      ) AS history_bookings
    FROM commutes c
    JOIN profiles p
      ON p.id = c.driver_id
    WHERE
      (
        c.driver_id = $1
        OR EXISTS (
          SELECT 1
          FROM ride_bookings rb_user
          WHERE rb_user.commute_id = c.id
            AND rb_user.passenger_id = $1
        )
      )
      AND c.status IN (
        'completed',
        'cancelled'
      )
    ORDER BY c.departure_at DESC
    `,
    [req.user.id],
  );

  res.json({
    commutes: result.rows,
  });
});

router.get('/active', requireAuth, async (req, res) => {
  const result = await query(
    `
    SELECT
  c.*,
p.display_name AS driver_name,
p.institution_name AS driver_institution,
(
  SELECT ROUND(AVG(r.score)::numeric, 1)
  FROM ratings r
  WHERE r.rated_id = c.driver_id
) AS driver_rating,
(
  SELECT COUNT(*)::int
  FROM ratings r
  WHERE r.rated_id = c.driver_id
) AS driver_rating_count,
  rb.status AS booking_status
FROM commutes c
JOIN profiles p
  ON p.id = c.driver_id
LEFT JOIN ride_bookings rb
      ON rb.commute_id = c.id
      AND rb.passenger_id = $1
    WHERE
      (
        c.driver_id = $1
        AND c.status IN ('open', 'full', 'started')
      )
      OR
      (
        rb.passenger_id = $1
        AND rb.status IN ('pending', 'confirmed', 'boarded')
        AND c.status IN ('open', 'full', 'started')
      )
    ORDER BY c.departure_at ASC
    LIMIT 1
    `,
    [req.user.id],
  );

  if (!result.rows[0]) {
    return res.json({
      active: false,
    });
  }

  const commute = result.rows[0];

  res.json({
    active: true,
    is_driver: commute.driver_id === req.user.id,
    commute,
  });
});

router.patch('/:id/complete', requireAuth, async (req, res) => {
  const result = await query(
    `UPDATE commutes
     SET status = 'completed',
         updated_at = NOW()
     WHERE id = $1
       AND driver_id = $2
       AND status = 'started'
     RETURNING *`,
    [req.params.id, req.user.id]
  );

  if (!result.rows[0]) {
    return res.status(400).json({
      error: 'Ride can only be completed after it has started',
    });
  }

  res.json({ commute: result.rows[0] });
});

router.patch('/:id/cancel', requireAuth, async (req, res) => {
  const result = await query(
    `UPDATE commutes
     SET
       status = 'cancelled',
       updated_at = NOW()
     WHERE id = $1
       AND driver_id = $2
     RETURNING *`,
    [
      req.params.id,
      req.user.id,
    ],
  );

  if (!result.rows[0]) {
    return res.status(404).json({
      error: 'Ride not found',
    });
  }

  res.json({
    commute: result.rows[0],
  });
});

router.patch('/:id/start', requireAuth, async (req, res) => {
  const commuteId = req.params.id;
  const client = await getPool().connect();

  try {
    await client.query('BEGIN');

    // Lock the commute while we start the ride and create
    // its safety sessions.
    const commuteResult = await client.query(
      `SELECT id, driver_id, status
       FROM commutes
       WHERE id = $1
       FOR UPDATE`,
      [commuteId],
    );

    const commute = commuteResult.rows[0];

    if (!commute) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'Ride not found',
      });
    }

    if (commute.driver_id !== req.user.id) {
      await client.query('ROLLBACK');

      return res.status(403).json({
        error: 'Only the driver can start this ride',
      });
    }

    if (!['open', 'full'].includes(commute.status)) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        error: `Ride cannot be started because it is ${commute.status}`,
      });
    }

    // Get every passenger who has actually boarded.
    const boardedPassengers = await client.query(
      `SELECT passenger_id
       FROM ride_bookings
       WHERE commute_id = $1
         AND status = 'boarded'`,
      [commuteId],
    );

    if (boardedPassengers.rows.length < 1) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        error: 'At least one boarded passenger is required to start the ride',
      });
    }

    // Start the ride.
    const result = await client.query(
      `UPDATE commutes
       SET
         status = 'started',
         updated_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [commuteId],
    );

    // Reject any passengers who never boarded.
    await client.query(
      `UPDATE ride_bookings
       SET status = 'rejected'
       WHERE commute_id = $1
         AND status = 'pending'`,
      [commuteId],
    );

    // ----------------------------------------------------------
    // CREATE SAFETY SESSION FOR THE DRIVER
    // ----------------------------------------------------------

    await client.query(
      `INSERT INTO trip_safety_sessions
          (commute_id, user_id, status)
       VALUES
          ($1, $2, 'active')
       ON CONFLICT (commute_id, user_id)
       DO NOTHING`,
      [
        commuteId,
        commute.driver_id,
      ],
    );

    // ----------------------------------------------------------
    // CREATE SAFETY SESSION FOR EVERY BOARDED PASSENGER
    // ----------------------------------------------------------

    for (const passenger of boardedPassengers.rows) {
      await client.query(
        `INSERT INTO trip_safety_sessions
            (commute_id, user_id, status)
         VALUES
            ($1, $2, 'active')
         ON CONFLICT (commute_id, user_id)
         DO NOTHING`,
        [
          commuteId,
          passenger.passenger_id,
        ],
      );
    }

    await client.query('COMMIT');

    return res.json({
      commute: result.rows[0],
      status: 'started',
      safety_sessions_created:
        boardedPassengers.rows.length + 1,
    });
  } catch (err) {
    await client.query('ROLLBACK');

    console.error(err);

    return res.status(500).json({
      error: 'Unable to start ride and create safety sessions.',
    });
  } finally {
    client.release();
  }
});

router.get('/:id/passengers', requireAuth, async (req, res) => {
  // Only the driver who owns the commute can view its passengers.
  const commute = await query(
    `SELECT id
     FROM commutes
     WHERE id = $1
       AND driver_id = $2`,
    [req.params.id, req.user.id],
  );

  if (!commute.rows[0]) {
    return res.status(403).json({
      error: 'Only the driver can view ride passengers',
    });
  }

  const result = await query(
    `SELECT
    rb.id AS booking_id,
    p.display_name,
    p.id,
    p.email,
    p.institution_name,
    p.avatar_url,
    p.gender AS passenger_gender,
    rb.travelling_mode,
    CASE
      WHEN rb.travelling_mode = 'someone_else'
      THEN rb.travelling_passenger_name
      ELSE p.display_name
    END AS travelling_passenger_name,
    CASE
      WHEN rb.travelling_mode = 'someone_else'
      THEN rb.travelling_passenger_gender
      ELSE p.gender
    END AS travelling_passenger_gender,
    COALESCE(
      (
        SELECT json_agg(
          json_build_object(
            'id', i.id,
            'name', i.name,
            'category', i.category,
            'icon', i.icon,
            'display_order', i.display_order
          )
          ORDER BY i.display_order ASC, i.name ASC
        )
        FROM profile_interests pi
        JOIN interests i ON i.id = pi.interest_id
        WHERE pi.profile_id = p.id
      ),
      '[]'::json
    ) AS passenger_interests,
    COALESCE(
      (
        SELECT json_agg(
          json_build_object(
            'id', i.id,
            'name', i.name,
            'category', i.category,
            'icon', i.icon,
            'display_order', i.display_order
          )
          ORDER BY i.display_order ASC, i.name ASC
        )
        FROM profile_interests pi
        JOIN interests i ON i.id = pi.interest_id
        JOIN profile_interests driver_pi
          ON driver_pi.interest_id = pi.interest_id
         AND driver_pi.profile_id = c.driver_id
        WHERE pi.profile_id = p.id
      ),
      '[]'::json
    ) AS common_interests,
    c.women_only,
    CASE
      WHEN rb.status IN ('confirmed', 'boarded')
      THEN p.phone_number
      ELSE NULL
    END AS phone_number,
    rb.seats,
    rb.amount_paise,
    rb.status,
    rb.payment_method,
    rb.payment_status,
    rb.boarded_at,
    rb.created_at,
    COALESCE(
      (
        SELECT json_agg(
          json_build_object(
            'id', bg.id,
            'name', bg.name,
            'gender', bg.gender
          )
          ORDER BY bg.created_at ASC
        )
        FROM booking_guests bg
        WHERE bg.booking_id = rb.id
      ),
      '[]'::json
    ) AS guests,
    (
      c.women_only = true
      AND (
        CASE
          WHEN rb.travelling_mode = 'someone_else'
          THEN rb.travelling_passenger_gender
          ELSE p.gender
        END IS DISTINCT FROM 'female'
        OR EXISTS (
          SELECT 1
          FROM booking_guests bg_notice
          WHERE bg_notice.booking_id = rb.id
            AND bg_notice.gender <> 'female'
        )
      )
    ) AS women_only_notice,
    (
      SELECT ROUND(AVG(r.score)::numeric, 1)
      FROM ratings r
      WHERE r.rated_id = p.id
    ) AS passenger_rating,
    (
      SELECT COUNT(*)::int
      FROM ratings r
      WHERE r.rated_id = p.id
    ) AS passenger_rating_count
     FROM ride_bookings rb
     JOIN profiles p
       ON p.id = rb.passenger_id
     JOIN commutes c
       ON c.id = rb.commute_id
     WHERE rb.commute_id = $1
     ORDER BY rb.created_at ASC`,
    [req.params.id],
  );

  res.json({
    passengers: result.rows,
  });
});

router.patch(
  '/:id/bookings/:bookingId/accept',
  requireAuth,
  async (req, res) => {
    const commuteId = req.params.id;
    const bookingId = req.params.bookingId;
    const client = await getPool().connect();

    try {
      // Keep the booking and commute locks until both records are updated.
      // Running SELECT ... FOR UPDATE through pool.query() autocommits after
      // that statement and therefore does not protect the later updates.
      await client.query('BEGIN');

      const result = await client.query(
        `SELECT
          rb.id,
          rb.commute_id,
          rb.passenger_id,
          rb.seats,
          rb.status,
          c.driver_id,
          c.seats_available,
          c.status AS commute_status
       FROM ride_bookings rb
       JOIN commutes c
         ON c.id = rb.commute_id
       WHERE rb.id = $1
         AND rb.commute_id = $2
       FOR UPDATE OF rb, c`,
        [bookingId, commuteId],
      );

      const booking = result.rows[0];

      if (!booking) {
        await client.query('ROLLBACK');
        return res.status(404).json({
          error: 'Booking not found',
        });
      }

      if (booking.driver_id !== req.user.id) {
        await client.query('ROLLBACK');
        return res.status(403).json({
          error: 'Only the driver can accept booking requests',
        });
      }

      if (booking.status !== 'pending') {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: `Booking is already ${booking.status}`,
        });
      }

      if (booking.commute_status !== 'open') {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: 'This ride is no longer accepting passengers',
        });
      }

      if (booking.seats_available < booking.seats) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: 'Not enough seats available',
        });
      }

      const boardingOtp = Math.floor(
        1000 + Math.random() * 9000,
      ).toString();

      const updatedBooking = await client.query(
        `UPDATE ride_bookings
   SET
     status = 'confirmed',
     boarding_otp = $2,
     boarded_at = NULL
   WHERE id = $1
   RETURNING *`,
        [
          bookingId,
          boardingOtp,
        ],
      );

      await client.query(
        `UPDATE commutes
       SET
         seats_available = seats_available - $1,
         status = CASE
           WHEN seats_available - $1 <= 0
           THEN 'full'
           ELSE status
         END,
         updated_at = NOW()
       WHERE id = $2`,
        [booking.seats, commuteId],
      );

      await client.query('COMMIT');

      res.json({
        booking: updatedBooking.rows[0],
        status: 'confirmed',
      });
    } catch (error) {
      await client.query('ROLLBACK').catch(() => { });
      console.error('Accept booking error:', error);
      res.status(500).json({
        error: 'Unable to accept booking',
      });
    } finally {
      client.release();
    }
  },
);

router.patch(
  '/:id/bookings/:bookingId/reject',
  requireAuth,
  async (req, res) => {
    const commuteId = req.params.id;
    const bookingId = req.params.bookingId;

    const result = await query(
      `SELECT
          rb.id,
          rb.status,
          c.driver_id
       FROM ride_bookings rb
       JOIN commutes c
         ON c.id = rb.commute_id
       WHERE rb.id = $1
         AND rb.commute_id = $2`,
      [bookingId, commuteId],
    );

    const booking = result.rows[0];

    if (!booking) {
      return res.status(404).json({
        error: 'Booking not found',
      });
    }

    if (booking.driver_id !== req.user.id) {
      return res.status(403).json({
        error: 'Only the driver can reject booking requests',
      });
    }

    if (booking.status !== 'pending') {
      return res.status(400).json({
        error: `Booking is already ${booking.status}`,
      });
    }

    const updatedBooking = await query(
      `UPDATE ride_bookings
       SET status = 'rejected'
       WHERE id = $1
       RETURNING *`,
      [bookingId],
    );

    res.json({
      booking: updatedBooking.rows[0],
      status: 'rejected',
    });
  },
);

router.post(
  '/:id/bookings/:bookingId/verify-otp',
  requireAuth,
  async (req, res) => {
    const commuteId = req.params.id;
    const bookingId = req.params.bookingId;
    const otp = String(req.body?.otp ?? '').trim();

    if (!/^\d{4}$/.test(otp)) {
      return res.status(400).json({
        error: 'Enter a valid 4-digit OTP',
      });
    }

    const bookingResult = await query(
      `SELECT
          rb.id,
          rb.commute_id,
          rb.passenger_id,
          rb.status,
          rb.boarding_otp,
          c.driver_id
       FROM ride_bookings rb
       JOIN commutes c
         ON c.id = rb.commute_id
       WHERE rb.id = $1
         AND rb.commute_id = $2`,
      [
        bookingId,
        commuteId,
      ],
    );

    const booking = bookingResult.rows[0];

    if (!booking) {
      return res.status(404).json({
        error: 'Booking not found',
      });
    }

    if (booking.driver_id !== req.user.id) {
      return res.status(403).json({
        error: 'Only the driver can verify a passenger OTP',
      });
    }

    if (booking.status === 'boarded') {
      return res.status(400).json({
        error: 'Passenger has already boarded',
      });
    }

    if (booking.status !== 'confirmed') {
      return res.status(400).json({
        error: `Passenger cannot board because booking is ${booking.status}`,
      });
    }

    if (!booking.boarding_otp) {
      return res.status(400).json({
        error: 'No boarding OTP found for this passenger',
      });
    }

    if (booking.boarding_otp !== otp) {
      return res.status(400).json({
        error: 'Incorrect OTP',
      });
    }

    const updatedBooking = await query(
      `UPDATE ride_bookings
       SET
         status = 'boarded',
         boarded_at = NOW(),
         boarding_otp = NULL
       WHERE id = $1
       RETURNING *`,
      [bookingId],
    );

    res.json({
      booking: updatedBooking.rows[0],
      status: 'boarded',
    });
  },
);

router.get('/ratings', requireAuth, async (req, res) => {
  const userId = req.user.id;

  const profileResult = await query(
    `SELECT
        id,
        display_name,
        rating,
        (
          SELECT COUNT(*)::int
          FROM ratings r
          WHERE r.rated_id = profiles.id
        ) AS rating_count
     FROM profiles
     WHERE id = $1`,
    [userId],
  );

  if (!profileResult.rows[0]) {
    return res.status(404).json({
      error: 'Profile not found',
    });
  }

  const profile = profileResult.rows[0];

  // People this user is still eligible to rate.
  // The NOT EXISTS checks are what make "Later" persistent.
  const pendingResult = await query(
    `SELECT
        c.id AS commute_id,
        c.departure_at,
        c.from_address,
        c.to_address,
        CASE
          WHEN c.driver_id = $1 THEN 'driver'
          ELSE 'passenger'
        END AS my_role,
        p.id AS person_id,
        p.display_name AS person_name,
        p.avatar_url,
        CASE
          WHEN c.driver_id = $1 THEN 'passenger'
          ELSE 'driver'
        END AS person_role
     FROM commutes c
     LEFT JOIN ride_bookings rb
       ON rb.commute_id = c.id
      AND rb.passenger_id = $1
     JOIN profiles p
       ON p.id = CASE
         WHEN c.driver_id = $1 THEN (
           SELECT rb2.passenger_id
           FROM ride_bookings rb2
           WHERE rb2.commute_id = c.id
             AND rb2.status = 'boarded'
             AND NOT EXISTS (
               SELECT 1
               FROM ratings rx
               WHERE rx.commute_id = c.id
                 AND rx.rater_id = $1
                 AND rx.rated_id = rb2.passenger_id
             )
           ORDER BY rb2.boarded_at ASC
           LIMIT 1
         )
         ELSE c.driver_id
       END
     WHERE c.status = 'completed'
       AND (
         (
           c.driver_id = $1
           AND EXISTS (
             SELECT 1
             FROM ride_bookings rb_driver
             WHERE rb_driver.commute_id = c.id
               AND rb_driver.status = 'boarded'
               AND NOT EXISTS (
                 SELECT 1
                 FROM ratings r_driver
                 WHERE r_driver.commute_id = c.id
                   AND r_driver.rater_id = $1
                   AND r_driver.rated_id = rb_driver.passenger_id
               )
           )
         )
         OR
         (
           rb.passenger_id = $1
           AND rb.status = 'boarded'
           AND NOT EXISTS (
             SELECT 1
             FROM ratings r_passenger
             WHERE r_passenger.commute_id = c.id
               AND r_passenger.rater_id = $1
               AND r_passenger.rated_id = c.driver_id
           )
         )
       )
     ORDER BY c.departure_at DESC`,
    [userId],
  );

  // The query above intentionally returns at most one pending passenger per
  // driver ride. Build the complete driver-side pending set separately so a
  // driver with multiple boarded passengers never loses pending ratings.
  const driverPendingResult = await query(
    `SELECT
        c.id AS commute_id,
        c.departure_at,
        c.from_address,
        c.to_address,
        'driver' AS my_role,
        p.id AS person_id,
        p.display_name AS person_name,
        p.avatar_url,
        'passenger' AS person_role
     FROM commutes c
     JOIN ride_bookings rb
       ON rb.commute_id = c.id
      AND rb.status = 'boarded'
     JOIN profiles p
       ON p.id = rb.passenger_id
     WHERE c.driver_id = $1
       AND c.status = 'completed'
       AND NOT EXISTS (
         SELECT 1
         FROM ride_bookings rb_unpaid
         WHERE rb_unpaid.commute_id = c.id
           AND rb_unpaid.status = 'boarded'
           AND rb_unpaid.payment_status <> 'received'
       )
       AND NOT EXISTS (
         SELECT 1
         FROM ratings r
         WHERE r.commute_id = c.id
           AND r.rater_id = $1
           AND r.rated_id = rb.passenger_id
       )
     ORDER BY c.departure_at DESC, rb.boarded_at ASC`,
    [userId],
  );

  const passengerPendingResult = await query(
    `SELECT
        c.id AS commute_id,
        c.departure_at,
        c.from_address,
        c.to_address,
        'passenger' AS my_role,
        p.id AS person_id,
        p.display_name AS person_name,
        p.avatar_url,
        'driver' AS person_role
     FROM ride_bookings rb
     JOIN commutes c
       ON c.id = rb.commute_id
     JOIN profiles p
       ON p.id = c.driver_id
     WHERE rb.passenger_id = $1
       AND rb.status = 'boarded'
       AND c.status = 'completed'
       AND NOT EXISTS (
         SELECT 1
         FROM ride_bookings rb_unpaid
         WHERE rb_unpaid.commute_id = c.id
           AND rb_unpaid.status = 'boarded'
           AND rb_unpaid.payment_status <> 'received'
       )
       AND NOT EXISTS (
         SELECT 1
         FROM ratings r
         WHERE r.commute_id = c.id
           AND r.rater_id = $1
           AND r.rated_id = c.driver_id
       )
     ORDER BY c.departure_at DESC`,
    [userId],
  );

  // Ratings the current user has given.
  const historyResult = await query(
    `SELECT
        r.id,
        r.commute_id,
        r.score,
        r.comment,
        r.created_at,
        c.departure_at,
        c.from_address,
        c.to_address,
        CASE
          WHEN c.driver_id = $1 THEN 'driver'
          ELSE 'passenger'
        END AS my_role,
        p.id AS person_id,
        p.display_name AS person_name,
        p.avatar_url,
        CASE
          WHEN c.driver_id = $1 THEN 'passenger'
          ELSE 'driver'
        END AS person_role
     FROM ratings r
     JOIN commutes c
       ON c.id = r.commute_id
     JOIN profiles p
       ON p.id = r.rated_id
     WHERE r.rater_id = $1
     ORDER BY r.created_at DESC`,
    [userId],
  );

  const pending = [
    ...driverPendingResult.rows,
    ...passengerPendingResult.rows,
  ].sort(
    (a, b) =>
      new Date(b.departure_at).getTime() -
      new Date(a.departure_at).getTime(),
  );

  return res.json({
    reputation: {
      rating: profile.rating,
      rating_count: Number(profile.rating_count ?? 0),
    },
    pending,
    history: historyResult.rows,
  });
});

// Get everyone the current user is allowed to rate for a completed ride.
// Get everyone the current user is allowed to rate for a completed ride.
router.get('/:id', optionalAuth, async (req, res) => {
  const result = await query(
    `SELECT
    c.*,
    p.display_name AS driver_name,
    p.institution_name AS driver_institution,
    (
      SELECT ROUND(AVG(r.score)::numeric, 1)
      FROM ratings r
      WHERE r.rated_id = c.driver_id
    ) AS driver_rating,
    (
      SELECT COUNT(*)::int
      FROM ratings r
      WHERE r.rated_id = c.driver_id
    ) AS driver_rating_count,
    COALESCE(
      (
        SELECT json_agg(
          json_build_object(
            'id', i.id,
            'name', i.name,
            'category', i.category,
            'icon', i.icon,
            'display_order', i.display_order
          )
          ORDER BY i.display_order ASC, i.name ASC
        )
        FROM profile_interests pi
        JOIN interests i ON i.id = pi.interest_id
        WHERE pi.profile_id = c.driver_id
      ),
      '[]'::json
    ) AS driver_interests,
    COALESCE(
      (
        SELECT json_agg(
          json_build_object(
            'id', i.id,
            'name', i.name,
            'category', i.category,
            'icon', i.icon,
            'display_order', i.display_order
          )
          ORDER BY i.display_order ASC, i.name ASC
        )
        FROM profile_interests pi
        JOIN interests i ON i.id = pi.interest_id
        JOIN profile_interests my_pi
          ON my_pi.interest_id = pi.interest_id
         AND my_pi.profile_id = $2
        WHERE pi.profile_id = c.driver_id
          AND $2::uuid IS NOT NULL
      ),
      '[]'::json
    ) AS common_interests,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM ride_bookings rb_call
        WHERE rb_call.commute_id = c.id
          AND rb_call.passenger_id = $2
          AND rb_call.status IN ('confirmed', 'boarded')
      )
      THEN p.phone_number
      ELSE NULL
    END AS driver_phone_number,
        CASE
          WHEN $2::uuid IS NULL THEN FALSE
          WHEN EXISTS (
            SELECT 1
            FROM ride_bookings rb
            WHERE rb.commute_id = c.id
              AND rb.passenger_id = $2
              AND rb.status IN ('pending', 'confirmed', 'boarded')
          )
          THEN TRUE
          ELSE FALSE
                END AS already_booked,
        (
  SELECT rb.status
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS booking_status,

(
  SELECT rb.boarding_otp
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
    AND rb.status = 'confirmed'
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS boarding_otp,(
  SELECT rb.id
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS booking_id,

(
  SELECT rb.payment_method
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS payment_method,

(
  SELECT rb.payment_status
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS payment_status,

(
  SELECT rb.seats
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS booking_seats,

(
  SELECT rb.amount_paise
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS booking_amount_paise,

(
  SELECT rb.travelling_mode
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS travelling_mode,

(
  SELECT rb.travelling_passenger_name
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS travelling_passenger_name,

(
  SELECT rb.travelling_passenger_gender
  FROM ride_bookings rb
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
  ORDER BY rb.created_at DESC
  LIMIT 1
) AS travelling_passenger_gender,

(
  SELECT COALESCE(
    json_agg(
      json_build_object(
        'id', bg.id,
        'name', bg.name,
        'gender', bg.gender
      )
      ORDER BY bg.created_at ASC
    ),
    '[]'::json
  )
  FROM booking_guests bg
  JOIN ride_bookings rb
    ON rb.id = bg.booking_id
  WHERE rb.commute_id = c.id
    AND rb.passenger_id = $2
) AS booking_guests

                  FROM commutes c
JOIN profiles p ON p.id = c.driver_id
     WHERE c.id = $1`,
    [req.params.id, req.user?.id ?? null],
  );

  if (!result.rows[0]) {
    return res.status(404).json({
      error: 'Commute not found',
    });
  }

  res.json({
    commute: result.rows[0],
  });
});

router.post('/:id/book', requireAuth, async (req, res) => {
  const commuteId = req.params.id;
  const client = await getPool().connect();

  try {
    const rawSeats = req.body?.seats;
    const guests = Array.isArray(req.body?.guests)
      ? req.body.guests
      : [];

    const travellingMode =
      typeof req.body?.travelling_mode === 'string'
        ? req.body.travelling_mode.trim().toLowerCase()
        : 'me';

    const travellingPassengerName =
      typeof req.body?.travelling_passenger_name === 'string'
        ? req.body.travelling_passenger_name.trim()
        : '';

    const travellingPassengerGender =
      typeof req.body?.travelling_passenger_gender === 'string'
        ? req.body.travelling_passenger_gender.trim().toLowerCase()
        : '';

    const seats = Number(rawSeats);

    if (!Number.isInteger(seats) || seats < 1) {
      return res.status(400).json({
        error: 'Seats must be a positive whole number',
        code: 'INVALID_SEATS',
      });
    }

    if (!['me', 'someone_else'].includes(travellingMode)) {
      return res.status(400).json({
        error: 'travelling_mode must be me or someone_else',
        code: 'INVALID_TRAVELLING_MODE',
      });
    }

    if (travellingMode === 'someone_else') {
      if (!travellingPassengerName) {
        return res.status(400).json({
          error: 'Travelling passenger name is required',
          code: 'INVALID_TRAVELLING_PASSENGER',
        });
      }

      if (travellingPassengerName.length > 100) {
        return res.status(400).json({
          error: 'Travelling passenger name is too long',
          code: 'INVALID_TRAVELLING_PASSENGER',
        });
      }

      if (!['male', 'female', 'other'].includes(travellingPassengerGender)) {
        return res.status(400).json({
          error: 'Travelling passenger has an invalid gender',
          code: 'INVALID_TRAVELLING_PASSENGER',
        });
      }
    }

    if (guests.length !== seats - 1) {
      return res.status(400).json({
        error: `A ${seats}-seat booking must include exactly ${seats - 1} guest(s)`,
        code: 'INVALID_GUEST_COUNT',
      });
    }

    for (let index = 0; index < guests.length; index += 1) {
      const guest = guests[index];

      const name =
        typeof guest?.name === 'string'
          ? guest.name.trim()
          : '';

      const gender =
        typeof guest?.gender === 'string'
          ? guest.gender.trim().toLowerCase()
          : '';

      if (!name) {
        return res.status(400).json({
          error: `Guest ${index + 1} name is required`,
          code: 'INVALID_GUEST',
        });
      }

      if (name.length > 100) {
        return res.status(400).json({
          error: `Guest ${index + 1} name is too long`,
          code: 'INVALID_GUEST',
        });
      }

      if (!['male', 'female', 'other'].includes(gender)) {
        return res.status(400).json({
          error: `Guest ${index + 1} has an invalid gender`,
          code: 'INVALID_GUEST',
        });
      }
    }

    await client.query('BEGIN');

    // Lock the commute so two simultaneous booking requests cannot
    // reserve the same remaining seats.
    const commuteRes = await client.query(
      `SELECT *
       FROM commutes
       WHERE id = $1
         AND status = 'open'
         AND vehicle_id IS NOT NULL
       FOR UPDATE`,
      [commuteId],
    );

    const commute = commuteRes.rows[0];

    if (!commute) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'Commute not available',
      });
    }

    if (commute.driver_id === req.user.id) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        error: 'Cannot book your own commute',
      });
    }

    if (seats > commute.seats_available) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        error: `Only ${commute.seats_available} seat(s) are available`,
        code: 'INSUFFICIENT_SEATS',
      });
    }

    const existingBooking = await client.query(
      `SELECT id, status
       FROM ride_bookings
       WHERE commute_id = $1
         AND passenger_id = $2`,
      [commuteId, req.user.id],
    );

    if (existingBooking.rows.length > 0) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        error: 'You have already booked this ride',
        code: 'ALREADY_BOOKED',
      });
    }

    // Make sure the passenger profile exists before checking gender.
    const passengerResult = await client.query(
      `SELECT id, gender
       FROM profiles
       WHERE id = $1`,
      [req.user.id],
    );

    if (!passengerResult.rows[0]) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        error: 'Complete your profile before booking a ride',
        code: 'PROFILE_REQUIRED',
      });
    }

    // Women-only rides are enforced server-side.
    // The actual travelling passenger must be female, whether the booking
    // is for the account holder or for someone else. Additional guests must
    // also be female. The Flutter UI performs the same check for UX, but this
    // backend check prevents bypassing it with a direct API request.
    if (commute.women_only === true) {
      const actualPassengerGender =
        travellingMode === 'someone_else'
          ? travellingPassengerGender
          : passengerResult.rows[0].gender?.trim().toLowerCase();

      if (actualPassengerGender !== 'female') {
        await client.query('ROLLBACK');

        return res.status(403).json({
          error: 'Women-only rides can only be booked for a female travelling passenger',
          code: 'WOMEN_ONLY_FEMALE_REQUIRED',
        });
      }

      const hasNonFemaleGuest = guests.some(
        (guest) => guest.gender.trim().toLowerCase() !== 'female',
      );

      if (hasNonFemaleGuest) {
        await client.query('ROLLBACK');

        return res.status(403).json({
          error: 'Women-only rides can only include female passengers',
          code: 'WOMEN_ONLY_FEMALE_GUEST_REQUIRED',
        });
      }
    }

    const amountPaise =
      commute.cost_per_seat_paise * seats;

    const bookingResult = await client.query(
      `INSERT INTO ride_bookings (
        commute_id,
        passenger_id,
        seats,
        amount_paise,
        status,
        travelling_mode,
        travelling_passenger_name,
        travelling_passenger_gender
      )
      VALUES ($1, $2, $3, $4, 'pending', $5, $6, $7)
      RETURNING *`,
      [
        commuteId,
        req.user.id,
        seats,
        amountPaise,
        travellingMode,
        travellingMode === 'someone_else' ? travellingPassengerName : null,
        travellingMode === 'someone_else' ? travellingPassengerGender : null,
      ],
    );

    const booking = bookingResult.rows[0];

    for (const guest of guests) {
      await client.query(
        `INSERT INTO booking_guests (
          booking_id,
          name,
          gender
        )
        VALUES ($1, $2, $3)`,
        [
          booking.id,
          guest.name.trim(),
          guest.gender.trim().toLowerCase(),
        ],
      );
    }

    await client.query('COMMIT');

    res.status(201).json({
      booking,
      amount_paise: amountPaise,
      guests,
      travelling_mode: travellingMode,
      travelling_passenger_name:
        travellingMode === 'someone_else' ? travellingPassengerName : null,
      travelling_passenger_gender:
        travellingMode === 'someone_else' ? travellingPassengerGender : null,
      women_only_notice:
        commute.women_only === true &&
        (
          (travellingMode === 'someone_else'
            ? travellingPassengerGender
            : passengerResult.rows[0].gender) !== 'female' ||
          guests.some((guest) => guest.gender.trim().toLowerCase() !== 'female')
        ),
    });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => { });
    console.error('Book commute error:', error);

    res.status(500).json({
      error: 'Unable to book commute',
    });
  } finally {
    client.release();
  }
});

router.delete('/:id/book', requireAuth, async (req, res) => {
  const commuteId = req.params.id;

  const booking = await query(
    `SELECT
        rb.*,
        c.status AS commute_status
     FROM ride_bookings rb
     JOIN commutes c
       ON c.id = rb.commute_id
     WHERE rb.commute_id = $1
       AND rb.passenger_id = $2`,
    [
      commuteId,
      req.user.id,
    ],
  );

  if (!booking.rows[0]) {
    return res.status(404).json({
      error: 'Booking not found',
    });
  }

  const currentBooking = booking.rows[0];

  if (!['pending', 'confirmed'].includes(currentBooking.status)) {
    return res.status(400).json({
      error: `Booking cannot be cancelled because it is ${currentBooking.status}`,
    });
  }

  if (
    !['open', 'full', 'started'].includes(
      currentBooking.commute_status,
    )
  ) {
    return res.status(400).json({
      error: 'This ride can no longer be cancelled',
    });
  }

  await query(
    `DELETE FROM ride_bookings
     WHERE id = $1`,
    [
      currentBooking.id,
    ],
  );

  if (currentBooking.status === 'confirmed') {
    if (currentBooking.commute_status === 'started') {
      await query(
        `UPDATE commutes
       SET
         seats_available = seats_available + $1,
         updated_at = NOW()
       WHERE id = $2`,
        [
          currentBooking.seats,
          commuteId,
        ],
      );
    } else {
      await query(
        `UPDATE commutes
       SET
         seats_available = seats_available + $1,
         status = 'open',
         updated_at = NOW()
       WHERE id = $2`,
        [
          currentBooking.seats,
          commuteId,
        ],
      );
    }
  }

  res.json({
    success: true,
  });
});

// ------------------------------------------------------------
// PAYMENTS
// ------------------------------------------------------------

// Select the payment method for a boarded passenger's booking.
// The passenger chooses between cash and UPI after the ride completes.
router.patch(
  '/:id/bookings/:bookingId/payment-method',
  requireAuth,
  async (req, res) => {
    const commuteId = req.params.id;
    const bookingId = req.params.bookingId;
    const paymentMethod = String(req.body?.payment_method ?? '')
      .trim()
      .toLowerCase();

    if (!['cash', 'upi'].includes(paymentMethod)) {
      return res.status(400).json({
        error: 'Payment method must be cash or upi',
      });
    }

    const result = await query(
      `SELECT
          rb.id,
          rb.passenger_id,
          rb.status,
          rb.payment_status
       FROM ride_bookings rb
       WHERE rb.id = $1
         AND rb.commute_id = $2`,
      [bookingId, commuteId],
    );

    const booking = result.rows[0];

    if (!booking) {
      return res.status(404).json({
        error: 'Booking not found',
      });
    }

    if (booking.passenger_id !== req.user.id) {
      return res.status(403).json({
        error: 'Only the passenger can choose the payment method',
      });
    }

    if (booking.status !== 'boarded') {
      return res.status(400).json({
        error: 'Payment is only available for boarded passengers',
      });
    }

    if (booking.payment_status === 'received') {
      return res.status(400).json({
        error: 'Payment has already been completed',
      });
    }

    const updatedBooking = await query(
      `UPDATE ride_bookings
       SET payment_method = $1
       WHERE id = $2
       RETURNING *`,
      [paymentMethod, bookingId],
    );

    res.json({
      booking: updatedBooking.rows[0],
      status: 'payment_method_selected',
    });
  },
);

// Mark a payment as completed.
//
// MVP behavior:
// - UPI: the passenger marks the payment done after paying externally.
// - Cash: the driver confirms that physical cash was received.
//
// This does not claim that CPool has verified an external UPI transaction.
router.patch(
  '/:id/bookings/:bookingId/payment-complete',
  requireAuth,
  async (req, res) => {
    const commuteId = req.params.id;
    const bookingId = req.params.bookingId;

    const result = await query(
      `SELECT
          rb.id,
          rb.passenger_id,
          rb.status,
          rb.payment_method,
          rb.payment_status,
          c.driver_id
       FROM ride_bookings rb
       JOIN commutes c
         ON c.id = rb.commute_id
       WHERE rb.id = $1
         AND rb.commute_id = $2`,
      [bookingId, commuteId],
    );

    const booking = result.rows[0];

    if (!booking) {
      return res.status(404).json({
        error: 'Booking not found',
      });
    }

    if (booking.status !== 'boarded') {
      return res.status(400).json({
        error: 'Payment is only available for boarded passengers',
      });
    }

    if (booking.payment_status === 'received') {
      return res.status(400).json({
        error: 'Payment has already been completed',
      });
    }

    if (!booking.payment_method) {
      return res.status(400).json({
        error: 'Select a payment method first',
      });
    }

    if (
      booking.payment_method === 'upi' &&
      booking.passenger_id !== req.user.id
    ) {
      return res.status(403).json({
        error: 'Only the passenger can mark this UPI payment as done',
      });
    }

    if (
      booking.payment_method === 'cash' &&
      booking.driver_id !== req.user.id
    ) {
      return res.status(403).json({
        error: 'Only the driver can confirm a cash payment',
      });
    }

    const updatedBooking = await query(
      `UPDATE ride_bookings
       SET payment_status = 'received'
       WHERE id = $1
       RETURNING *`,
      [bookingId],
    );

    res.json({
      booking: updatedBooking.rows[0],
      status: 'payment_received',
    });
  },
);

// Return payment status for every boarded passenger in the ride.
router.get('/:id/payments', requireAuth, async (req, res) => {
  const commuteId = req.params.id;

  const commute = await query(
    `SELECT id, driver_id, status
     FROM commutes
     WHERE id = $1`,
    [commuteId],
  );

  const ride = commute.rows[0];

  if (!ride) {
    return res.status(404).json({
      error: 'Ride not found',
    });
  }

  if (ride.driver_id !== req.user.id) {
    return res.status(403).json({
      error: 'Only the driver can view all ride payments',
    });
  }

  const result = await query(
    `SELECT
        rb.id AS booking_id,
        rb.passenger_id,
        p.display_name,
        rb.amount_paise,
        rb.payment_method,
        rb.payment_status
     FROM ride_bookings rb
     JOIN profiles p
       ON p.id = rb.passenger_id
     WHERE rb.commute_id = $1
       AND rb.status = 'boarded'
     ORDER BY rb.boarded_at ASC`,
    [commuteId],
  );

  res.json({
    payments: result.rows,
  });
});

// ------------------------------------------------------------
// RATINGS
// ------------------------------------------------------------

// Return the current user's reputation, pending ratings, and rating history.
//
// "Pending" is intentionally derived from completed rides + eligibility +
// absence of an existing rating. This means pressing "Later" does not need
// a separate database flag. The item simply remains pending until rated.

router.get('/:id/rating-eligible', requireAuth, async (req, res) => {
  const commuteId = req.params.id;
  const userId = req.user.id;

  // Get the ride.
  const commuteResult = await query(
    `SELECT id, driver_id, status
     FROM commutes
     WHERE id = $1`,
    [commuteId],
  );

  const commute = commuteResult.rows[0];

  if (!commute) {
    return res.status(404).json({
      error: 'Ride not found',
    });
  }

  // Ratings are available only after the ride is completed.
  if (commute.status !== 'completed') {
    return res.status(400).json({
      error: 'Ratings are only available after the ride is completed',
    });
  }

  const unpaidResult = await query(
    `SELECT COUNT(*)::int AS count
     FROM ride_bookings
     WHERE commute_id = $1
       AND status = 'boarded'
       AND payment_status <> 'received'`,
    [commuteId],
  );

  if (unpaidResult.rows[0].count > 0) {
    return res.status(400).json({
      error: 'Complete all passenger payments before rating',
    });
  }

  // ----------------------------------------------------------
  // DRIVER:
  // Can rate only passengers who actually boarded.
  // ----------------------------------------------------------
  if (commute.driver_id === userId) {
    const passengersResult = await query(
      `SELECT
          p.id,
          p.display_name,
          p.avatar_url,
          (
            SELECT ROUND(AVG(rp.score)::numeric, 1)
            FROM ratings rp
            WHERE rp.rated_id = p.id
          ) AS rating,
          (
            SELECT COUNT(*)::int
            FROM ratings rp
            WHERE rp.rated_id = p.id
          ) AS rating_count,
          r.id AS rating_id
       FROM ride_bookings rb
       JOIN profiles p
         ON p.id = rb.passenger_id
       LEFT JOIN ratings r
         ON r.commute_id = rb.commute_id
        AND r.rater_id = $2
        AND r.rated_id = p.id
       WHERE rb.commute_id = $1
         AND rb.status = 'boarded'
       ORDER BY rb.boarded_at ASC`,
      [commuteId, userId],
    );

    return res.json({
      role: 'driver',
      people: passengersResult.rows.map((passenger) => ({
        ...passenger,
        already_rated: passenger.rating_id != null,
      })),
    });
  }

  // ----------------------------------------------------------
  // PASSENGER:
  // Must have actually boarded to rate the driver.
  // ----------------------------------------------------------
  const bookingResult = await query(
    `SELECT
        rb.id,
        rb.status,
        r.id AS rating_id
     FROM ride_bookings rb
     LEFT JOIN ratings r
       ON r.commute_id = rb.commute_id
      AND r.rater_id = $2
      AND r.rated_id = $3
     WHERE rb.commute_id = $1
       AND rb.passenger_id = $2`,
    [commuteId, userId, commute.driver_id],
  );

  const booking = bookingResult.rows[0];

  if (!booking || booking.status !== 'boarded') {
    return res.status(403).json({
      error: 'Only passengers who boarded this ride can rate the driver',
    });
  }

  const driverResult = await query(
    `SELECT
        id,
        display_name,
        avatar_url,
        (
          SELECT ROUND(AVG(r.score)::numeric, 1)
          FROM ratings r
          WHERE r.rated_id = profiles.id
        ) AS rating,
        (
          SELECT COUNT(*)::int
          FROM ratings r
          WHERE r.rated_id = profiles.id
        ) AS rating_count
     FROM profiles
     WHERE id = $1`,
    [commute.driver_id],
  );

  const driver = driverResult.rows[0];

  return res.json({
    role: 'passenger',
    people: [
      {
        ...driver,
        already_rated: booking.rating_id != null,
      },
    ],
  });
});

// Submit a rating.
router.post('/:id/ratings', requireAuth, async (req, res) => {
  const commuteId = req.params.id;
  const raterId = req.user.id;

  const {
    rated_id,
    score,
    comment,
  } = req.body;

  // Basic score validation.
  if (!Number.isInteger(score) || score < 1 || score > 5) {
    return res.status(400).json({
      error: 'Rating score must be an integer between 1 and 5',
    });
  }

  if (!rated_id) {
    return res.status(400).json({
      error: 'rated_id is required',
    });
  }

  if (rated_id === raterId) {
    return res.status(400).json({
      error: 'You cannot rate yourself',
    });
  }

  // Get ride.
  const commuteResult = await query(
    `SELECT id, driver_id, status
     FROM commutes
     WHERE id = $1`,
    [commuteId],
  );

  const commute = commuteResult.rows[0];

  if (!commute) {
    return res.status(404).json({
      error: 'Ride not found',
    });
  }

  if (commute.status !== 'completed') {
    return res.status(400).json({
      error: 'Ratings are only available after the ride is completed',
    });
  }

  const unpaidResult = await query(
    `SELECT COUNT(*)::int AS count
     FROM ride_bookings
     WHERE commute_id = $1
       AND status = 'boarded'
       AND payment_status <> 'received'`,
    [commuteId],
  );

  if (unpaidResult.rows[0].count > 0) {
    return res.status(400).json({
      error: 'Complete all passenger payments before rating',
    });
  }

  let isAllowed = false;

  // ----------------------------------------------------------
  // DRIVER rating a passenger.
  // Passenger must have boarded.
  // ----------------------------------------------------------
  if (commute.driver_id === raterId) {
    const passengerResult = await query(
      `SELECT id
       FROM ride_bookings
       WHERE commute_id = $1
         AND passenger_id = $2
         AND status = 'boarded'`,
      [commuteId, rated_id],
    );

    isAllowed = passengerResult.rows.length > 0;
  } else {
    // --------------------------------------------------------
    // PASSENGER rating the driver.
    // Passenger must have boarded.
    // --------------------------------------------------------
    if (rated_id === commute.driver_id) {
      const passengerResult = await query(
        `SELECT id
         FROM ride_bookings
         WHERE commute_id = $1
           AND passenger_id = $2
           AND status = 'boarded'`,
        [commuteId, raterId],
      );

      isAllowed = passengerResult.rows.length > 0;
    }
  }

  if (!isAllowed) {
    return res.status(403).json({
      error: 'You are not allowed to rate this user for this ride',
    });
  }

  // Insert independent rating.
  const ratingResult = await query(
    `INSERT INTO ratings (
        commute_id,
        rater_id,
        rated_id,
        score,
        comment
     )
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (commute_id, rater_id, rated_id)
     DO NOTHING
     RETURNING *`,
    [
      commuteId,
      raterId,
      rated_id,
      score,
      comment?.trim() || null,
    ],
  );

  if (!ratingResult.rows[0]) {
    return res.status(409).json({
      error: 'You have already rated this user for this ride',
    });
  }

  // Calculate the rated user's new independent average.
  const averageResult = await query(
    `SELECT
        ROUND(AVG(score)::numeric, 1) AS average_rating,
        COUNT(*)::int AS rating_count
     FROM ratings
     WHERE rated_id = $1`,
    [rated_id],
  );

  const ratingStats = averageResult.rows[0];

  // Update cached profile rating.
  await query(
    `UPDATE profiles
     SET rating = $1,
         updated_at = NOW()
     WHERE id = $2`,
    [
      ratingStats.average_rating,
      rated_id,
    ],
  );

  res.status(201).json({
    rating: ratingResult.rows[0],
    average_rating: ratingStats.average_rating,
    rating_count: ratingStats.rating_count,
  });
});

export default router;