-- =====================================================
-- 019_create_vehicles.sql
-- Multiple Vehicle Management
-- =====================================================

CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4 (),
    user_id UUID NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
    vehicle_type TEXT NOT NULL CHECK (
        vehicle_type IN ('car', 'bike')
    ),
    vehicle_name TEXT NOT NULL,
    vehicle_number TEXT NOT NULL UNIQUE,
    vehicle_color TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON vehicles (user_id);

CREATE INDEX IF NOT EXISTS idx_vehicles_user_created ON vehicles (user_id, created_at ASC);

-- =====================================================
-- Migrate existing driver vehicles
-- =====================================================

INSERT INTO
    vehicles (
        user_id,
        vehicle_type,
        vehicle_name,
        vehicle_number,
        vehicle_color,
        created_at,
        updated_at
    )
SELECT
    user_id,
    vehicle_type,
    vehicle_name,
    vehicle_number,
    vehicle_color,
    created_at,
    updated_at
FROM
    driver_details ON CONFLICT (vehicle_number) DO NOTHING;

-- =====================================================
-- Attach a vehicle to each commute
-- =====================================================

ALTER TABLE commutes
ADD COLUMN IF NOT EXISTS vehicle_id UUID REFERENCES vehicles (id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_commutes_vehicle_id ON commutes (vehicle_id);

-- =====================================================
-- Backfill existing commutes
-- Each existing driver's commute gets their migrated
-- driver-details vehicle.
-- =====================================================

UPDATE commutes c
SET
    vehicle_id = v.id
FROM vehicles v
WHERE
    c.driver_id = v.user_id
    AND c.vehicle_id IS NULL;