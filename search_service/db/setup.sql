-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create restaurants table
CREATE TABLE IF NOT EXISTS public.restaurants (
    "RestaurantID" text PRIMARY KEY,
    "Name" text NOT NULL,
    "CuisineType" text,
    "Country" text,
    "City" text,
    "Address" text,
    "Rating" float,
    "BusinessStatus" text,
    "latitude" float,
    "longitude" float,
    "PriceLevel" integer,
    "website" text,
    "location" geography(Point, 4326)
);

-- Create index for spatial queries
CREATE INDEX IF NOT EXISTS restaurants_location_idx ON public.restaurants USING GIST (location);

-- Create index for cuisine type
CREATE INDEX IF NOT EXISTS restaurants_cuisine_idx ON public.restaurants ("CuisineType");

-- Create index for price level
CREATE INDEX IF NOT EXISTS restaurants_price_idx ON public.restaurants ("PriceLevel");

-- Create index for rating
CREATE INDEX IF NOT EXISTS restaurants_rating_idx ON public.restaurants ("Rating");

-- Enable RLS
ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;

-- Create policy to allow read access to authenticated users
CREATE POLICY "Allow read access for authenticated users"
ON public.restaurants FOR SELECT
TO authenticated
USING (true); 