-- CPool repair migration:
-- Migration 022 may already be recorded in schema_migrations even though
-- its travelling-passenger columns are missing from ride_bookings.
-- This migration safely repairs that state.

ALTER TABLE ride_bookings
ADD COLUMN IF NOT EXISTS travelling_mode TEXT NOT NULL DEFAULT 'me',
ADD COLUMN IF NOT EXISTS travelling_passenger_name TEXT,
ADD COLUMN IF NOT EXISTS travelling_passenger_gender TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ride_bookings_travelling_mode_check'
      AND conrelid = 'ride_bookings'::regclass
  ) THEN
    ALTER TABLE ride_bookings
      ADD CONSTRAINT ride_bookings_travelling_mode_check
      CHECK (travelling_mode IN ('me', 'someone_else'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ride_bookings_travelling_gender_check'
      AND conrelid = 'ride_bookings'::regclass
  ) THEN
    ALTER TABLE ride_bookings
      ADD CONSTRAINT ride_bookings_travelling_gender_check
      CHECK (
        travelling_passenger_gender IS NULL
        OR travelling_passenger_gender IN ('male', 'female', 'other')
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ride_bookings_travelling_passenger_check'
      AND conrelid = 'ride_bookings'::regclass
  ) THEN
    ALTER TABLE ride_bookings
      ADD CONSTRAINT ride_bookings_travelling_passenger_check
      CHECK (
        (travelling_mode = 'me'
          AND travelling_passenger_name IS NULL
          AND travelling_passenger_gender IS NULL)
        OR
        (travelling_mode = 'someone_else'
          AND travelling_passenger_name IS NOT NULL
          AND length(btrim(travelling_passenger_name)) > 0
          AND travelling_passenger_gender IS NOT NULL)
      );
  END IF;
END $$;