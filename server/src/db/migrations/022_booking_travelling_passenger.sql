-- CPool: distinguish the account holder from the person actually travelling.
-- Existing bookings remain normal "me" bookings through the default value.

ALTER TABLE ride_bookings
ADD COLUMN travelling_mode TEXT NOT NULL DEFAULT 'me',
ADD COLUMN travelling_passenger_name TEXT,
ADD COLUMN travelling_passenger_gender TEXT;

ALTER TABLE ride_bookings
ADD CONSTRAINT ride_bookings_travelling_mode_check CHECK (
    travelling_mode IN ('me', 'someone_else')
);

ALTER TABLE ride_bookings
ADD CONSTRAINT ride_bookings_travelling_gender_check CHECK (
    travelling_passenger_gender IS NULL
    OR travelling_passenger_gender IN ('male', 'female', 'other')
);

ALTER TABLE ride_bookings
ADD CONSTRAINT ride_bookings_travelling_passenger_check CHECK (
    (
        travelling_mode = 'me'
        AND travelling_passenger_name IS NULL
        AND travelling_passenger_gender IS NULL
    )
    OR (
        travelling_mode = 'someone_else'
        AND travelling_passenger_name IS NOT NULL
        AND length(
            btrim (travelling_passenger_name)
        ) > 0
        AND travelling_passenger_gender IS NOT NULL
    )
);