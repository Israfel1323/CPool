-- CPool Customer Support v1 (Migration 014)
CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id UUID NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
    commute_id UUID NULL REFERENCES commutes (id) ON DELETE SET NULL,
    category TEXT NOT NULL CHECK (
        category IN (
            'Payment',
            'Ride',
            'Booking',
            'Account',
            'Safety',
            'Other'
        )
    ),
    description TEXT NOT NULL CHECK (
        char_length(trim(description)) >= 5
    ),
    status TEXT NOT NULL DEFAULT 'open' CHECK (
        status IN ('open', 'resolved')
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON support_tickets (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_support_tickets_commute ON support_tickets (commute_id);

CREATE TABLE IF NOT EXISTS support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    ticket_id UUID NOT NULL REFERENCES support_tickets (id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL CHECK (
        sender_role IN ('user', 'operations')
    ),
    message TEXT NOT NULL CHECK (
        char_length(trim(message)) >= 1
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_messages_ticket ON support_messages (ticket_id, created_at ASC);

CREATE OR REPLACE FUNCTION set_support_ticket_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_support_ticket_updated_at ON support_tickets;

CREATE TRIGGER trg_support_ticket_updated_at
BEFORE UPDATE ON support_tickets
FOR EACH ROW
EXECUTE FUNCTION set_support_ticket_updated_at();