-- ============================================
-- UNIFIED VERIFICATION CENTER
-- ============================================

-- Add verification type
ALTER TABLE verification_requests
ADD COLUMN IF NOT EXISTS verification_type TEXT;

-- Add reference id
ALTER TABLE verification_requests
ADD COLUMN IF NOT EXISTS reference_id UUID;

-- Default existing rows to student
UPDATE verification_requests
SET verification_type = 'student'
WHERE verification_type IS NULL;

-- Make verification_type mandatory
ALTER TABLE verification_requests
ALTER COLUMN verification_type SET NOT NULL;

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_verification_status
ON verification_requests(status);

CREATE INDEX IF NOT EXISTS idx_verification_type
ON verification_requests(verification_type);

CREATE INDEX IF NOT EXISTS idx_verification_user
ON verification_requests(profile_id);