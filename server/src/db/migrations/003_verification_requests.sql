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
END
$$;

CREATE TABLE IF NOT EXISTS verification_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    profile_id UUID NOT NULL
        REFERENCES profiles(id)
        ON DELETE CASCADE,

    storage_path TEXT NOT NULL,

    status verification_status NOT NULL DEFAULT 'pending',

    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    reviewed_at TIMESTAMPTZ,

    reviewed_by UUID,

    review_notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_verification_profile
ON verification_requests(profile_id);

CREATE INDEX IF NOT EXISTS idx_verification_status
ON verification_requests(status);