ALTER TABLE verification_requests
ADD COLUMN IF NOT EXISTS verification_type TEXT;

UPDATE verification_requests
SET verification_type = 'student'
WHERE verification_type IS NULL;

ALTER TABLE verification_requests
ALTER COLUMN verification_type SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_verification_type
ON verification_requests(verification_type);
-- Prevent duplicate verification requests
CREATE UNIQUE INDEX IF NOT EXISTS
idx_unique_profile_verification
ON verification_requests(profile_id, verification_type);