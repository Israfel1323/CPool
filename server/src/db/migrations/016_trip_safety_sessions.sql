CREATE TABLE trip_safety_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    commute_id UUID NOT NULL
        REFERENCES commutes(id)
        ON DELETE CASCADE,

    user_id UUID NOT NULL
        REFERENCES profiles(id)
        ON DELETE CASCADE,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'cancelled')),

    share_token UUID NOT NULL DEFAULT gen_random_uuid()
        UNIQUE,

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    ended_at TIMESTAMPTZ,

    expires_at TIMESTAMPTZ,

    latest_latitude DOUBLE PRECISION,

    latest_longitude DOUBLE PRECISION,

    last_location_update_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (commute_id, user_id)
);

CREATE INDEX idx_trip_safety_sessions_commute_id
    ON trip_safety_sessions(commute_id);

CREATE INDEX idx_trip_safety_sessions_user_id
    ON trip_safety_sessions(user_id);

CREATE INDEX idx_trip_safety_sessions_status
    ON trip_safety_sessions(status);

CREATE INDEX idx_trip_safety_sessions_share_token
    ON trip_safety_sessions(share_token);