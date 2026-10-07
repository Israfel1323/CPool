-- Migration 020: preserve vehicle identity on each commute.
--
-- A commute keeps the exact vehicle details used when it was created.
-- The current vehicles table can therefore be edited or deleted later
-- without changing historical ride details.

ALTER TABLE commutes
    ADD COLUMN IF NOT EXISTS vehicle_type TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_name TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_number TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_color TEXT;

-- Backfill existing commutes from their currently linked vehicle.
UPDATE commutes c
SET
    vehicle_type = v.vehicle_type,
    vehicle_name = v.vehicle_name,
    vehicle_number = v.vehicle_number,
    vehicle_color = v.vehicle_color
FROM vehicles v
WHERE c.vehicle_id = v.id
  AND (
      c.vehicle_type IS NULL
      OR c.vehicle_name IS NULL
      OR c.vehicle_number IS NULL
      OR c.vehicle_color IS DISTINCT FROM v.vehicle_color
  );

-- Keep vehicle_id as an optional link to the current vehicle record.
-- Deleting the current vehicle must not delete the commute.
ALTER TABLE commutes
    DROP CONSTRAINT IF EXISTS commutes_vehicle_id_fkey;

ALTER TABLE commutes
    ADD CONSTRAINT commutes_vehicle_id_fkey
    FOREIGN KEY (vehicle_id)
    REFERENCES vehicles(id)
    ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_commutes_vehicle_id
    ON commutes (vehicle_id);
