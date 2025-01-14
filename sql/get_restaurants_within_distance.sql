-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_restaurants_location ON restaurants USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_restaurants_cuisine_type ON restaurants USING GIN (cuisine_type);
CREATE INDEX IF NOT EXISTS idx_restaurants_availability_date ON restaurants_availability (date);
CREATE INDEX IF NOT EXISTS idx_restaurants_availability_time_slot ON restaurants_availability (time_slot);
CREATE INDEX IF NOT EXISTS idx_restaurants_dietary_stats_id ON restaurants_dietary_stats(id);

-- Set statement timeout to 30 seconds
SET statement_timeout = '30s';

-- Drop ALL variations of the function to ensure no conflicts
DROP FUNCTION IF EXISTS get_restaurants_within_distance_v4(text, float, text[], text, text, text, text);
DROP FUNCTION IF EXISTS get_restaurants_within_distance_v4(text, float, text[], text, text, text, text, text);
DROP FUNCTION IF EXISTS get_restaurants_within_distance_v4(text, float, text[], text, text);
DROP FUNCTION IF EXISTS get_restaurants_within_distance_v4(text, float, text[]);
DROP FUNCTION IF EXISTS get_restaurants_within_distance_v4(geometry, float, text[], text, text, text, text);

CREATE OR REPLACE FUNCTION get_restaurants_within_distance_v4(
    ref_point text,
    max_distance float,
    excluded_cuisines text[],
    required_cuisines text[],
    start_date_str text,
    end_date_str text,
    start_time_str text,
    end_time_str text
) RETURNS TABLE (
    id text,
    name text,
    address text,
    rating float,
    price_level bigint,
    cuisine_type text[],
    business_status text,
    website text,
    latitude float,
    longitude float,
    distance float,
    available_slots json,
    area text,
    vegetarian_Scale text
) AS $$
DECLARE
    v_start_date date;
    v_end_date date;
    v_start_time time;
    v_end_time time;
BEGIN
    -- Convert input strings to proper date/time types
    v_start_date := CAST(NULLIF(start_date_str, '') AS date);
    v_end_date := CAST(NULLIF(end_date_str, '') AS date);
    v_start_time := COALESCE(CAST(start_time_str AS time), '00:00:00'::time);
    v_end_time := COALESCE(CAST(end_time_str AS time), '23:59:59'::time);

    RETURN QUERY
    WITH restaurant_distances AS (
        SELECT 
            r.id as rd_id,
            r.name as rd_name,
            r.address as rd_address,
            r.rating as rd_rating,
            r.price_level as rd_price_level,
            r.cuisine_type as rd_cuisine_type,
            r.business_status as rd_business_status,
            r.website as rd_website,
            r.location as rd_location,
            r.area as rd_area,
            ST_Distance(
                r.location::geometry,
                ST_SetSRID(ST_GeomFromText(ref_point), 4326),
                true
            ) as rd_distance
        FROM restaurants r
        WHERE ST_DWithin(
            r.location::geometry,
            ST_SetSRID(ST_GeomFromText(ref_point), 4326),
            max_distance
        )
        AND NOT EXISTS (
            SELECT 1
            FROM unnest(excluded_cuisines) ec
            WHERE EXISTS (
                SELECT 1
                FROM unnest(r.cuisine_type) ct
                WHERE UPPER(ct) = UPPER(ec)
            )
        )
        AND (
            required_cuisines IS NULL
            OR array_length(required_cuisines, 1) IS NULL
            OR EXISTS (
                SELECT 1
                FROM unnest(required_cuisines) rc
                WHERE EXISTS (
                    SELECT 1
                    FROM unnest(r.cuisine_type) ct
                    WHERE UPPER(ct) = UPPER(rc)
                )
            )
        )
    ),
    availability_slots AS (
        SELECT 
            ra.id as as_restaurant_id,
            json_agg(
                json_build_object(
                    'date', to_char(CAST(ra.date AS date), 'YYYY-MM-DD'),
                    'time_slot', to_char(CAST(ra.time_slot AS time), 'HH24:MI:SS'),
                    'uuid', ra.uuid
                )
            ) as as_slots
        FROM restaurants_availability ra
        WHERE CAST(ra.date AS date) BETWEEN v_start_date AND v_end_date
        AND CAST(ra.time_slot AS time) BETWEEN v_start_time AND v_end_time
        GROUP BY ra.id
    )
    SELECT 
        rd.rd_id as id,
        rd.rd_name as name,
        rd.rd_address as address,
        rd.rd_rating as rating,
        rd.rd_price_level as price_level,
        rd.rd_cuisine_type as cuisine_type,
        rd.rd_business_status as business_status,
        rd.rd_website as website,
        ST_Y(rd.rd_location::geometry) as latitude,
        ST_X(rd.rd_location::geometry) as longitude,
        rd.rd_distance as distance,
        COALESCE(a.as_slots, '[]'::json) as available_slots,
        rd.rd_area as area,
        rds.vegetarian_Scale
    FROM restaurant_distances rd
    LEFT JOIN availability_slots a ON a.as_restaurant_id = rd.rd_id
    LEFT JOIN restaurants_dietary_stats rds ON TRIM(rds.id) = TRIM(rd.rd_id)
    ORDER BY rd.rd_distance;
END;
$$ LANGUAGE plpgsql;