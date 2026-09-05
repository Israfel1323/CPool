import { Router } from 'express';
import { query } from '../db/pool.js';
import { optionalAuth, requireAuth } from '../middleware/auth.js';

const router = Router();

router.get('/', optionalAuth, async (req, res) => {
  const { from_lat, from_lng, to_lat, to_lng, pool_type, women_only } = req.query;

  let sql = `
    SELECT c.*, p.display_name AS driver_name,
p.institution_name AS driver_institution, p.driver_verified
    FROM commutes c
    JOIN profiles p ON p.id = c.driver_id
    WHERE c.status = 'open' AND c.departure_at > NOW() AND c.seats_available > 0`;
  const params = [];

  if (req.user) {
    params.push(req.user.id);
    sql += ` AND c.driver_id <> $${params.length}`;
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

  sql += ' ORDER BY c.departure_at ASC LIMIT 50';

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
  } = req.body;

  if (!from_address || !to_address || departure_at == null) {
    return res.status(400).json({
      error: 'Missing required commute fields',
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
      notes
    )
    VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$10,$11,$12,$13
    )
    RETURNING *`,
    [
      req.user.id,
      from_address,
      to_address,
      Number(from_lat),
      Number(from_lng),
      Number(to_lat),
      Number(to_lng),
      pool_type,
      Boolean(women_only),
      Number(seats_total),
      Number(cost_per_seat_paise),
      departure_at,
      notes ?? null,
    ],
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
    SELECT DISTINCT
      c.*,
      p.display_name AS driver_name,
p.institution_name AS driver_institution
    FROM commutes c
    JOIN profiles p
      ON p.id = c.driver_id
    LEFT JOIN ride_bookings rb
      ON rb.commute_id = c.id
    WHERE
      (
        c.driver_id = $1
        OR rb.passenger_id = $1
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
dd.vehicle_type,
  dd.vehicle_name,
  dd.vehicle_number,
  dd.vehicle_color,
  rb.status AS booking_status
FROM commutes c
JOIN profiles p
  ON p.id = c.driver_id
LEFT JOIN driver_details dd
  ON dd.user_id = c.driver_id
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
     SET
       status = 'completed',
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

  if (commute.driver_id !== req.user.id) {
    return res.status(403).json({
      error: 'Only the driver can start this ride',
    });
  }

  if (!['open', 'full'].includes(commute.status)) {
    return res.status(400).json({
      error: `Ride cannot be started because it is ${commute.status}`,
    });
  }

  const boardedPassengers = await query(
    `SELECT COUNT(*)::int AS count
     FROM ride_bookings
     WHERE commute_id = $1
       AND status = 'boarded'`,
    [commuteId],
  );

  if (boardedPassengers.rows[0].count < 1) {
    return res.status(400).json({
      error: 'At least one boarded passenger is required to start the ride',
    });
  }

  const result = await query(
    `UPDATE commutes
     SET
       status = 'started',
       updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [commuteId],
  );

  await query(
    `UPDATE ride_bookings
     SET status = 'rejected'
     WHERE commute_id = $1
       AND status = 'pending'`,
    [commuteId],
  );

  res.json({
    commute: result.rows[0],
    status: 'started',
  });
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
        rb.seats,
        rb.amount_paise,
        rb.status,
        rb.boarded_at,
        rb.created_at
     FROM ride_bookings rb
     JOIN profiles p
       ON p.id = rb.passenger_id
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

    const result = await query(
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
      return res.status(404).json({
        error: 'Booking not found',
      });
    }

    if (booking.driver_id !== req.user.id) {
      return res.status(403).json({
        error: 'Only the driver can accept booking requests',
      });
    }

    if (booking.status !== 'pending') {
      return res.status(400).json({
        error: `Booking is already ${booking.status}`,
      });
    }

    if (booking.commute_status !== 'open') {
      return res.status(400).json({
        error: 'This ride is no longer accepting passengers',
      });
    }

    if (booking.seats_available < booking.seats) {
      return res.status(400).json({
        error: 'Not enough seats available',
      });
    }

    const boardingOtp = Math.floor(
      1000 + Math.random() * 9000,
    ).toString();


    const updatedBooking = await query(
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

    await query(
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

    res.json({
      booking: updatedBooking.rows[0],
      status: 'confirmed',
    });
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
router.get('/:id', optionalAuth, async (req, res) => {
  const result = await query(
    `SELECT
        c.*,
p.display_name AS driver_name,
p.institution_name AS driver_institution,
dd.vehicle_type,
dd.vehicle_name,
dd.vehicle_number,
dd.vehicle_color,
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
) AS booking_id
         FROM commutes c
JOIN profiles p ON p.id = c.driver_id
LEFT JOIN driver_details dd ON dd.user_id = c.driver_id
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
  const seats = 1;
  const commuteId = req.params.id;

  const commuteRes = await query(
    `SELECT * FROM commutes
     WHERE id = $1
     AND status = 'open'`,
    [commuteId],
  );
  const commute = commuteRes.rows[0];

  if (!commute) {
    return res.status(404).json({
      error: 'Commute not available',
    });
  }

  if (commute.driver_id === req.user.id) {
    return res.status(400).json({
      error: 'Cannot book your own commute',
    });
  }
  const existingBooking = await query(
    `SELECT id
   FROM ride_bookings
   WHERE commute_id = $1
   AND passenger_id = $2`,
    [commuteId, req.user.id],
  );

  if (existingBooking.rows.length > 0) {
    return res.status(400).json({
      error: 'You have already booked this ride',
    });
  }
  const amountPaise =
    commute.cost_per_seat_paise * seats;

  const booking = await query(
    `INSERT INTO ride_bookings (
      commute_id,
      passenger_id,
      seats,
      amount_paise,
      status
    )
    VALUES ($1, $2, $3, $4, 'pending')
    ON CONFLICT (commute_id, passenger_id)
    DO UPDATE SET
      seats = EXCLUDED.seats
    RETURNING *`,
    [
      commuteId,
      req.user.id,
      seats,
      amountPaise,
    ],
  );

  res.status(201).json({
    booking: booking.rows[0],
    amount_paise: amountPaise,
  });
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
// RATINGS
// ------------------------------------------------------------

// Get everyone the current user is allowed to rate for a completed ride.
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
    `SELECT id, display_name, avatar_url
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