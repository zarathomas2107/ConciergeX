-- Create restaurants table if it doesn't exist
CREATE TABLE IF NOT EXISTS restaurants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "Name" TEXT NOT NULL,
    "CuisineType" TEXT NOT NULL,
    "Address" TEXT NOT NULL,
    "Rating" NUMERIC(3,1) NOT NULL,
    "PriceLevel" INTEGER NOT NULL,
    location GEOGRAPHY(POINT) NOT NULL,
    "Features" TEXT[] DEFAULT '{}'::TEXT[]
);

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Insert sample data
INSERT INTO restaurants ("Name", "CuisineType", "Address", "Rating", "PriceLevel", location, "Features")
VALUES
    ('Taj Mahal', 'Indian', '123 Main St', 4.5, 2, ST_SetSRID(ST_MakePoint(-73.935242, 40.730610), 4326), ARRAY['vegetarian', 'delivery']),
    ('Golden Dragon', 'Chinese', '456 Oak Ave', 4.2, 2, ST_SetSRID(ST_MakePoint(-73.936242, 40.731610), 4326), ARRAY['delivery']),
    ('Bella Italia', 'Italian', '789 Pine Rd', 4.7, 3, ST_SetSRID(ST_MakePoint(-73.934242, 40.729610), 4326), ARRAY['romantic', 'wine-bar']),
    ('Curry House', 'Indian', '321 Elm St', 4.3, 1, ST_SetSRID(ST_MakePoint(-73.933242, 40.728610), 4326), ARRAY['spicy', 'takeout']),
    ('Sushi Ko', 'Japanese', '654 Maple Dr', 4.8, 4, ST_SetSRID(ST_MakePoint(-73.932242, 40.727610), 4326), ARRAY['sushi-bar', 'romantic']); 