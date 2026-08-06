-- =====================================================
-- 008_roles_system.sql
-- Operations & Role Management
-- =====================================================

-- Add role column to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS role VARCHAR(30) NOT NULL DEFAULT 'user';

-- Promote primary administrator
UPDATE profiles
SET role = 'admin'
WHERE email = 'omar.afeef654@gmail.com';

-- Helpful index for admin lookups
CREATE INDEX IF NOT EXISTS idx_profiles_role
ON profiles(role);