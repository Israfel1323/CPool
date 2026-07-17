-- CPool MVP schema

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  student_verified BOOLEAN NOT NULL DEFAULT FALSE,
  driver_verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TYPE pool_type AS ENUM ('carpool', 'bikepool', 'studentpool');
CREATE TYPE commute_status AS ENUM ('open', 'full', 'completed', 'cancelled');

CREATE TABLE IF NOT EXISTS commutes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  from_address TEXT NOT NULL,
  to_address TEXT NOT NULL,
  from_lat DOUBLE PRECISION NOT NULL,
  from_lng DOUBLE PRECISION NOT NULL,
  to_lat DOUBLE PRECISION NOT NULL,
  to_lng DOUBLE PRECISION NOT NULL,
  pool_type pool_type NOT NULL DEFAULT 'carpool',
  women_only BOOLEAN NOT NULL DEFAULT FALSE,
  seats_total INT NOT NULL DEFAULT 3,
  seats_available INT NOT NULL DEFAULT 3,
  cost_per_seat_paise INT NOT NULL DEFAULT 0,
  departure_at TIMESTAMPTZ NOT NULL,
  status commute_status NOT NULL DEFAULT 'open',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_commutes_departure ON commutes(departure_at);
CREATE INDEX IF NOT EXISTS idx_commutes_status ON commutes(status);

CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'completed', 'cancelled');

CREATE TABLE IF NOT EXISTS ride_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commute_id UUID NOT NULL REFERENCES commutes(id) ON DELETE CASCADE,
  passenger_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  seats INT NOT NULL DEFAULT 1,
  amount_paise INT NOT NULL DEFAULT 0,
  status booking_status NOT NULL DEFAULT 'pending',
  razorpay_order_id TEXT,
  razorpay_payment_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (commute_id, passenger_id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commute_id UUID NOT NULL REFERENCES commutes(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_commute ON chat_messages(commute_id, created_at);

CREATE TABLE IF NOT EXISTS ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commute_id UUID NOT NULL REFERENCES commutes(id) ON DELETE CASCADE,
  rater_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  rated_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  score INT NOT NULL CHECK (score >= 1 AND score <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (commute_id, rater_id, rated_id)
);
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'verification_status'
    ) THEN
        CREATE TYPE verification_status AS ENUM (
            'pending',
            'approved',
            'rejected'
        );
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS verification_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  profile_id UUID NOT NULL
    REFERENCES profiles(id)
    ON DELETE CASCADE,

  institution_name TEXT NOT NULL,

  id_card_url TEXT NOT NULL,

  status verification_status
    NOT NULL DEFAULT 'pending',

  reviewed_by UUID
    REFERENCES profiles(id),

  reviewed_at TIMESTAMPTZ,

  rejection_reason TEXT,

  created_at TIMESTAMPTZ
    NOT NULL DEFAULT NOW(),

  updated_at TIMESTAMPTZ
    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_verification_profile
ON verification_requests(profile_id);

CREATE INDEX IF NOT EXISTS idx_verification_status
ON verification_requests(status);
