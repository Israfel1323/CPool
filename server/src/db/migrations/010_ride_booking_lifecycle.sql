-- Add explicit rejection state for ride booking requests.
ALTER TYPE booking_status
ADD VALUE IF NOT EXISTS 'rejected';