-- Insert availability data for March 2025
WITH restaurant_ids AS (
    SELECT id::text FROM restaurants
),
dates AS (
    SELECT generate_series(
        '2025-03-01'::date,
        '2025-03-31'::date,
        INTERVAL '1 day'
    )::date AS date
),
time_slots AS (
    SELECT time '12:00:00' + (INTERVAL '30 minutes' * generate_series(0, 19)) AS time_slot
)
INSERT INTO restaurants_availability (id, date, time_slot)
SELECT 
    r.id,
    d.date,
    t.time_slot
FROM restaurant_ids r
CROSS JOIN dates d
CROSS JOIN time_slots t
WHERE t.time_slot BETWEEN '12:00:00' AND '22:00:00'
ON CONFLICT DO NOTHING; 