-- Function to execute dynamic SQL commands
CREATE OR REPLACE FUNCTION exec_sql(sql_string text)
RETURNS void AS $$
BEGIN
    EXECUTE sql_string;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search restaurants with various filters
CREATE OR REPLACE FUNCTION search_restaurants(
    p_cuisine_type text DEFAULT NULL,
    p_price_level integer DEFAULT NULL,
    p_venue_lat numeric DEFAULT NULL,
    p_venue_lon numeric DEFAULT NULL,
    p_dietary_requirements text[] DEFAULT NULL,
    p_excluded_cuisines text[] DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    name text,
    cuisine_type text,
    address text,
    rating numeric,
    price_level integer,
    latitude numeric,
    longitude numeric,
    features jsonb,
    distance numeric
) AS $$
BEGIN
    RETURN QUERY
    WITH base_query AS (
        SELECT 
            r.*,
            CASE 
                WHEN p_venue_lat IS NOT NULL AND p_venue_lon IS NOT NULL THEN
                    ST_Distance(
                        ST_SetSRID(ST_MakePoint(r.longitude, r.latitude), 4326)::geography,
                        ST_SetSRID(ST_MakePoint(p_venue_lon, p_venue_lat), 4326)::geography
                    )
                ELSE NULL
            END as distance
        FROM restaurants r
        WHERE 
            -- Cuisine type filter
            (p_cuisine_type IS NULL OR r.cuisine_type = p_cuisine_type)
            -- Price level filter
            AND (p_price_level IS NULL OR r.price_level <= p_price_level)
            -- Dietary requirements filter
            AND (p_dietary_requirements IS NULL OR 
                 (SELECT bool_and(r.features->>req = 'true') 
                  FROM unnest(p_dietary_requirements) req))
            -- Excluded cuisines filter
            AND (p_excluded_cuisines IS NULL OR 
                 r.cuisine_type NOT IN (SELECT unnest(p_excluded_cuisines)))
    )
    SELECT *
    FROM base_query
    ORDER BY 
        CASE 
            WHEN distance IS NOT NULL THEN distance
            ELSE -rating  -- Order by rating DESC when distance is not available
        END
    LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 