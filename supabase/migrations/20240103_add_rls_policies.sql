-- Enable RLS on the tables
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurants_availability ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow public read access to restaurants" ON restaurants;
DROP POLICY IF EXISTS "Allow public read access to restaurants_availability" ON restaurants_availability;

-- Create policies for restaurants table
CREATE POLICY "Allow public read access to restaurants"
ON restaurants FOR SELECT
TO anon
USING (true);

-- Create policies for restaurants_availability table
CREATE POLICY "Allow public read access to restaurants_availability"
ON restaurants_availability FOR SELECT
TO anon
USING (true);

-- Grant necessary permissions to anon role
GRANT SELECT ON restaurants TO anon;
GRANT SELECT ON restaurants_availability TO anon;

-- Grant execute permission on the function with complete signature
GRANT EXECUTE ON FUNCTION get_restaurants_within_distance_v2(text, float, text[], text, text, text, text) TO anon; 