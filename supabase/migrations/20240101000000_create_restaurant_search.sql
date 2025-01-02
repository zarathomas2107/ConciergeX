-- Enable PostGIS if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create function to find restaurants near a venue using PostGIS
CREATE OR REPLACE FUNCTION find_restaurants_near_venue(
    venue_lat double precision,
    venue_lon double precision,
    excluded_cuisines text[] DEFAULT NULL,
    max_results integer DEFAULT 200
)
RETURNS TABLE (
    id text,
    name text,
    cuisine_type text,
    rating numeric,
    price_level integer,
    address text,
    latitude double precision,
    longitude double precision,
    distance_meters double precision
) AS $$
BEGIN
    RETURN QUERY
    WITH restaurant_distances AS (
        SELECT 
            r."RestaurantID" as id,
            r."Name" as name,
            r."CuisineType" as cuisine_type,
            r."Rating"::numeric as rating,
            r."PriceLevel"::integer as price_level,
            r."Address" as address,
            r."latitude"::double precision as latitude,
            r."longitude"::double precision as longitude,
            ST_Distance(
                ST_SetSRID(ST_MakePoint(r."longitude"::double precision, r."latitude"::double precision), 4326)::geography,
                ST_SetSRID(ST_MakePoint(venue_lon, venue_lat), 4326)::geography
            ) as distance
        FROM restaurants r
        WHERE 
            -- Exclude specified cuisines (case insensitive)
            (excluded_cuisines IS NULL OR NOT (LOWER(r."CuisineType") = ANY(SELECT LOWER(unnest(excluded_cuisines)))))
    )
    SELECT 
        rd.id,
        rd.name,
        rd.cuisine_type,
        rd.rating,
        rd.price_level,
        rd.address,
        rd.latitude,
        rd.longitude,
        rd.distance as distance_meters
    FROM restaurant_distances rd
    WHERE rd.distance <= 5000  -- 5km radius
    ORDER BY rd.distance
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql; 