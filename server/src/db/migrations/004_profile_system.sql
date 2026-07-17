-- =====================================================
-- 004_profile_system.sql
-- Expands the profiles table for CPool Profile System
-- =====================================================

-- Personal Information
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS full_name TEXT;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS phone_number TEXT;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS institution TEXT NOT NULL DEFAULT 'MGIT';

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS branch TEXT;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS roll_number TEXT;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS admission_year INTEGER;

-- Profile State
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN NOT NULL DEFAULT FALSE;

-- Reputation
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS rating NUMERIC(2,1) NOT NULL DEFAULT 5.0;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS total_rides INTEGER NOT NULL DEFAULT 0;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS completed_rides INTEGER NOT NULL DEFAULT 0;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS cancelled_rides INTEGER NOT NULL DEFAULT 0;

-- Roll number must be unique
ALTER TABLE profiles
ADD CONSTRAINT profiles_roll_number_unique
UNIQUE (roll_number);