import { Router } from 'express';
import Razorpay from 'razorpay';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

function getRazorpay() {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keyId || !keySecret) return null;
  return new Razorpay({ key_id: keyId, key_secret: keySecret });
}

/** Create Razorpay order for a booking */
router.post('/orders', requireAuth, async (req, res) => {
  const razorpay = getRazorpay();
  if (!razorpay) {
    return res.status(503).json({
      error: 'Razorpay not configured',
      hint: 'Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in server .env',
    });
  }

  const { booking_id } = req.body;
  if (!booking_id) return res.status(400).json({ error: 'booking_id required' });

  const bookingRes = await query(
    `SELECT b.*, c.from_address, c.to_address
     FROM ride_bookings b
     JOIN commutes c ON c.id = b.commute_id
     WHERE b.id = $1 AND b.passenger_id = $2`,
    [booking_id, req.user.id],
  );
  const booking = bookingRes.rows[0];
  if (!booking) return res.status(404).json({ error: 'Booking not found' });
  if (booking.amount_paise < 1) {
    return res.status(400).json({ error: 'Nothing to pay for this booking' });
  }

  const order = await razorpay.orders.create({
    amount: booking.amount_paise,
    currency: 'INR',
    receipt: `booking_${booking.id.slice(0, 8)}`,
    notes: {
      booking_id: booking.id,
      commute_id: booking.commute_id,
      user_id: req.user.id,
    },
  });


  res.json({
    order_id: order.id,
    amount: order.amount,
    currency: order.currency,
    key_id: process.env.RAZORPAY_KEY_ID,
    booking_id: booking.id,
    description: `CPool: ${booking.from_address} → ${booking.to_address}`,
  });
});

/** Client confirms payment — MVP stores payment id (verify signature in production) */
router.post('/confirm', requireAuth, async (req, res) => {
  const { booking_id, razorpay_payment_id, razorpay_order_id } = req.body;
  if (!booking_id || !razorpay_payment_id) {
    return res.status(400).json({ error: 'booking_id and razorpay_payment_id required' });
  }

  const result = await query(
    `UPDATE ride_bookings
     SET razorpay_payment_id = $3, razorpay_order_id = COALESCE($4, razorpay_order_id), status = 'confirmed'
     WHERE id = $1 AND passenger_id = $2
     RETURNING *`,
    [booking_id, req.user.id, razorpay_payment_id, razorpay_order_id ?? null],
  );

  if (!result.rows[0]) return res.status(404).json({ error: 'Booking not found' });

  const booking = result.rows[0];
  await query(
    `UPDATE commutes SET seats_available = seats_available - $2, updated_at = NOW()
     WHERE id = $1`,
    [booking.commute_id, booking.seats],
  );

  res.json({ booking: result.rows[0], status: 'confirmed' });
});

export default router;
