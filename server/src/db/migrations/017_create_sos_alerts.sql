CREATE TABLE sos_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    trip_safety_session_id UUID NOT NULL
        REFERENCES trip_safety_sessions(id)
        ON DELETE CASCADE,

    commute_id UUID NOT NULL
        REFERENCES commutes(id)
        ON DELETE CASCADE,

    user_id UUID NOT NULL
        REFERENCES profiles(id)
        ON DELETE CASCADE,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'resolved', 'cancelled')),

    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,

    message TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

CREATE INDEX idx_sos_alerts_session_id
    ON sos_alerts(trip_safety_session_id);

CREATE INDEX idx_sos_alerts_commute_id
    ON sos_alerts(commute_id);

CREATE INDEX idx_sos_alerts_user_id
    ON sos_alerts(user_id);