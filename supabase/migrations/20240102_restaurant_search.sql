-- Drop existing functions
DROP FUNCTION IF EXISTS find_restaurants_near_venue(double precision, double precision);
DROP FUNCTION IF EXISTS find_restaurants_near_venue(double precision, double precision, text[], text[], integer);
DROP FUNCTION IF EXISTS find_restaurants_near_venue(double precision, double precision, text[], text[], date, date, time, time, integer);
DROP FUNCTION IF EXISTS find_restaurants_near_venue(double precision, double precision, text[], text[], text[], date, date, time, time, integer);

-- Create updated function that includes availability information
CREATE OR REPLACE FUNCTION find_restaurants_near_venue(
    venue_lat double precision,
    venue_lon double precision,
    excluded_cuisines text[] DEFAULT NULL,
    cuisine_types text[] DEFAULT NULL,
    dietary_requirements text[] DEFAULT NULL,
    start_date date DEFAULT NULL,
    end_date date DEFAULT NULL,
    start_time time DEFAULT NULL,
    end_time time DEFAULT NULL,
    max_results integer DEFAULT 200
)
RETURNS TABLE (
    "RestaurantID" text,
    "Name" text,
    "CuisineType" text,
    "PriceLevel" smallint,
    "Rating" double precision,
    "Address" text,
    "latitude" double precision,
    "longitude" double precision,
    distance double precision,
    available_slots json  -- New field to return availability info
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH restaurant_distances AS (
        SELECT 
            r."RestaurantID",
            r."Name",
            COALESCE(r."CuisineType", 'Other') as "CuisineType",
            r."PriceLevel",
            r."Rating",
            r."Address",
            r.latitude,
            r.longitude,
            ST_Distance(
                ST_SetSRID(ST_MakePoint(r.longitude, r.latitude), 4326)::geography,
                ST_SetSRID(ST_MakePoint(venue_lon, venue_lat), 4326)::geography
            ) as distance
        FROM restaurants r
        LEFT JOIN restaurants_dietary_compliance dc ON r."RestaurantID" = dc.restaurant_id
        WHERE 
            -- Cuisine filters
            (cuisine_types IS NULL OR r."CuisineType" = ANY(cuisine_types))
            AND
            (excluded_cuisines IS NULL OR NOT (r."CuisineType" = ANY(excluded_cuisines)))
            AND
            -- Dietary requirements filter
            (dietary_requirements IS NULL OR (
                CASE 
                    WHEN 'vegetarian' = ANY(dietary_requirements) THEN dc.vegetarian = true
                    ELSE true
                END AND
                CASE 
                    WHEN 'vegan' = ANY(dietary_requirements) THEN dc.vegan = true
                    ELSE true
                END AND
                CASE 
                    WHEN 'halal' = ANY(dietary_requirements) THEN dc.halal = true
                    ELSE true
                END AND
                CASE 
                    WHEN 'kosher' = ANY(dietary_requirements) THEN dc.kosher = true
                    ELSE true
                END AND
                CASE 
                    WHEN 'gluten_free' = ANY(dietary_requirements) THEN dc.gluten_free = true
                    ELSE true
                END AND
                CASE 
                    WHEN 'dairy_free' = ANY(dietary_requirements) THEN dc.dairy_free = true
                    ELSE true
                END AND
                CASE 
                    WHEN 'nut_free' = ANY(dietary_requirements) THEN dc.nut_free = true
                    ELSE true
                END
            ))
    ),
    availability_info AS (
        -- Get availability information for each restaurant
        SELECT 
            ra."RestaurantID",
            json_agg(
                json_build_object(
                    'date', ra.date,
                    'time_slot', ra.time_slot,
                    'available_seats', (ra.total_capacity - ra.booked_seats)
                )
                ORDER BY ra.date, ra.time_slot
            ) as slots
        FROM restaurants_availability ra
        WHERE (start_date IS NULL OR ra.date BETWEEN start_date AND end_date)
        AND (
            start_time IS NULL 
            OR end_time IS NULL 
            OR ra.time_slot::time BETWEEN start_time AND end_time
        )
        AND ra.is_available = true
        AND (ra.total_capacity - ra.booked_seats) > 0
        GROUP BY ra."RestaurantID"
        HAVING COUNT(*) > 0  -- Only include restaurants with at least one available slot
    )
    SELECT 
        rd."RestaurantID",
        rd."Name",
        rd."CuisineType",
        rd."PriceLevel"::smallint,
        rd."Rating",
        rd."Address",
        rd.latitude,
        rd.longitude,
        rd.distance,
        ai.slots as available_slots
    FROM restaurant_distances rd
    INNER JOIN availability_info ai ON ai."RestaurantID" = rd."RestaurantID"  -- Changed to INNER JOIN
    WHERE rd.distance <= 5000  -- Within 5km
    ORDER BY rd.distance
    LIMIT max_results;
END;
$$; 