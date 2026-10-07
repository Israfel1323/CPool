-- ============================================================
-- Migration 021: Booking Guests + Profile Gender
-- ============================================================

-- Add gender to user profiles.
-- This is used for women-only ride eligibility checks.
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS gender TEXT;

ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_gender_check;

ALTER TABLE profiles
ADD CONSTRAINT profiles_gender_check
CHECK (
    gender IS NULL
    OR gender IN ('male', 'female', 'other')
);


-- ============================================================
-- Booking guests
-- ============================================================

CREATE TABLE IF NOT EXISTS booking_guests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    booking_id UUID NOT NULL
        REFERENCES ride_bookings(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,
    gender TEXT NOT NULL
        CHECK (gender IN ('male', 'female', 'other')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- Quickly retrieve guests belonging to a booking.
CREATE INDEX IF NOT EXISTS idx_booking_guests_booking_id
ON booking_guests (booking_id);


-- Keep guest count consistent with the booking.
-- A booking with N seats can have at most N - 1 guests.
CREATE OR REPLACE FUNCTION validate_booking_guest_count()
RETURNS TRIGGER AS $$
DECLARE
    booking_seats INT;
    guest_count INT;
BEGIN
    SELECT seats
    INTO booking_seats
    FROM ride_bookings
    WHERE id = NEW.booking_id;

    SELECT COUNT(*)
    INTO guest_count
    FROM booking_guests
    WHERE booking_id = NEW.booking_id;

    IF guest_count > booking_seats - 1 THEN
        RAISE EXCEPTION
            'A booking with % seat(s) can have at most % guest(s)',
            booking_seats,
            booking_seats - 1;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trg_validate_booking_guest_count
ON booking_guests;

CREATE TRIGGER trg_validate_booking_guest_count
AFTER INSERT OR UPDATE
ON booking_guests
FOR EACH ROW
EXECUTE FUNCTION validate_booking_guest_count();