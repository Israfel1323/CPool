-- =====================================================
-- 009_admin_audit_logs.sql
-- Operations Audit Logs
-- =====================================================

CREATE TABLE IF NOT EXISTS operations_audit_logs (

    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    admin_profile_id UUID NOT NULL
        REFERENCES profiles(id)
        ON DELETE CASCADE,

    target_profile_id UUID
        REFERENCES profiles(id)
        ON DELETE SET NULL,

    action VARCHAR(50) NOT NULL,

    entity_type VARCHAR(50) NOT NULL,

    entity_id UUID,

    reason TEXT,

    status VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',

    ip_address TEXT,

    user_agent TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

);

CREATE INDEX IF NOT EXISTS idx_operations_logs_admin
ON operations_audit_logs(admin_profile_id);

CREATE INDEX IF NOT EXISTS idx_operations_logs_target
ON operations_audit_logs(target_profile_id);

CREATE INDEX IF NOT EXISTS idx_operations_logs_action
ON operations_audit_logs(action);

CREATE INDEX IF NOT EXISTS idx_operations_logs_created
ON operations_audit_logs(created_at DESC);