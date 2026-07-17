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

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_verification_profile
ON verification_requests(profile_id);

CREATE INDEX IF NOT EXISTS idx_verification_status
ON verification_requests(status);