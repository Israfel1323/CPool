-- Add payment tracking for each passenger booking.

ALTER TABLE ride_bookings
ADD COLUMN IF NOT EXISTS payment_method TEXT
CHECK (payment_method IN ('cash', 'upi'));

ALTER TABLE ride_bookings
ADD COLUMN IF NOT EXISTS payment_status TEXT
NOT NULL DEFAULT 'pending'
CHECK (payment_status IN ('pending', 'received'));