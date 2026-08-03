-- =====================================================
-- 005_driver_details.sql
-- Driver Verification & Vehicle Details
-- =====================================================

CREATE TABLE IF NOT EXISTS driver_details (
    user_id UUID PRIMARY KEY
        REFERENCES profiles(id)
        ON DELETE CASCADE,

    vehicle_type TEXT NOT NULL
        CHECK (vehicle_type IN ('car', 'bike')),

    vehicle_name TEXT NOT NULL,

    vehicle_number TEXT NOT NULL UNIQUE,

    vehicle_color TEXT,

    license_front_url TEXT,

    license_back_url TEXT,

    verification_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (verification_status IN ('pending', 'approved', 'rejected')),

    verified_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_details_status
ON driver_details (verification_status);