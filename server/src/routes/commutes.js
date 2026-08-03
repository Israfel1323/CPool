import { Router } from 'express';
import { query } from '../db/pool.js';
import { optionalAuth, requireAuth } from '../middleware/auth.js';

const router = Router();

router.get('/', optionalAuth, async (req, res) => {
  const { from_lat, from_lng, to_lat, to_lng, pool_type, women_only } = req.query;

  let sql = `
    SELECT c.*, p.display_name AS driver_name, p.driver_verified
    FROM commutes c
    JOIN profiles p ON p.id = c.driver_id
    WHERE c.status = 'open' AND c.departure_at > NOW() AND c.seats_available > 0`;
  const params = [];

  if (req.user) {
    params.push(req.user.id);
    sql += ` AND c.driver_id <> $${params.length}`;
  }
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
     WHERE passenger_id = $1`,
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
    `SELECT c.*, p.display_name AS driver_name
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
      p.display_name AS driver_name
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
router.get('/:id/passengers', requireAuth, async (req, res) => {
  const result = await query(
    `SELECT
        p.id,
        p.display_name,
        p.email,
        rb.seats,
        rb.status
     FROM ride_bookings rb
     JOIN profiles p
       ON p.id = rb.passenger_id
     WHERE rb.commute_id = $1`,
    [req.params.id],
  );

  res.json({
    passengers: result.rows,
  });
});
router.get('/:id', async (req, res) => {
  const result = await query(
    `SELECT c.*, p.display_name AS driver_name
     FROM commutes c
     JOIN profiles p ON p.id = c.driver_id
     WHERE c.id = $1`,
    [req.params.id],
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

  if (commute.seats_available < seats) {
    return res.status(400).json({
      error: 'Not enough seats',
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

  // NEW: Reduce available seats
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
    [seats, commuteId],
  );

  res.status(201).json({
    booking: booking.rows[0],
    amount_paise: amountPaise,
  });
});
router.delete('/:id/book', requireAuth, async (req, res) => {
  const commuteId = req.params.id;

  const booking = await query(
    `SELECT *
     FROM ride_bookings
     WHERE commute_id = $1
     AND passenger_id = $2`,
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

  const seats = booking.rows[0].seats;

  await query(
    `DELETE FROM ride_bookings
     WHERE id = $1`,
    [
      booking.rows[0].id,
    ],
  );

  await query(
    `UPDATE commutes
     SET
       seats_available = seats_available + $1,
       status = 'open',
       updated_at = NOW()
     WHERE id = $2`,
    [
      seats,
      commuteId,
    ],
  );

  res.json({
    success: true,
  });
});

export default router;