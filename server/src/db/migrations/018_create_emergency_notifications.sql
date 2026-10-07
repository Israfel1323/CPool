CREATE TABLE IF NOT EXISTS emergency_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    sos_alert_id UUID NOT NULL
        REFERENCES sos_alerts(id)
        ON DELETE CASCADE,

    emergency_contact_id UUID NOT NULL
        REFERENCES emergency_contacts(id)
        ON DELETE CASCADE,

    channel TEXT NOT NULL DEFAULT 'sms'
        CHECK (channel IN ('sms')),

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'sent',
                'failed',
                'not_configured'
            )
        ),

    recipient TEXT NOT NULL,

    message TEXT NOT NULL,

    provider TEXT,

    provider_message_id TEXT,

    error_message TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    sent_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_emergency_notifications_sos_alert
    ON emergency_notifications(sos_alert_id);

CREATE INDEX IF NOT EXISTS idx_emergency_notifications_contact
    ON emergency_notifications(emergency_contact_id);

CREATE INDEX IF NOT EXISTS idx_emergency_notifications_status
    ON emergency_notifications(status);