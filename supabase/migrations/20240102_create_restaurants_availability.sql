-- Create restaurants_availability table
CREATE TABLE IF NOT EXISTS restaurants_availability (
    uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id TEXT NOT NULL,
    date DATE NOT NULL,
    time_slot TIME NOT NULL,
    FOREIGN KEY (id) REFERENCES restaurants(id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_restaurants_availability_id ON restaurants_availability(id);
CREATE INDEX IF NOT EXISTS idx_restaurants_availability_date ON restaurants_availability(date);
CREATE INDEX IF NOT EXISTS idx_restaurants_availability_time_slot ON restaurants_availability(time_slot);

-- Insert sample data for the next 7 days
WITH restaurant_ids AS (
    SELECT id::text FROM restaurants
),
dates AS (
    SELECT generate_series(
        CURRENT_DATE,
        CURRENT_DATE + INTERVAL '7 days',
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

-- Enable RLS
ALTER TABLE restaurants_availability ENABLE ROW LEVEL SECURITY;

-- Create policy to allow authenticated users to read availability data
CREATE POLICY "Allow authenticated users to read availability" 
ON restaurants_availability
FOR SELECT
TO authenticated
USING (true); 