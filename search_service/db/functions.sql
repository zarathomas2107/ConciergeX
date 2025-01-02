-- Enable the pg_vector extension if not already enabled
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable the pg_trgm extension for text similarity search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enable PostGIS extension for spatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Add a search_text column to cinemas table that concatenates name and chain
ALTER TABLE cinemas ADD COLUMN IF NOT EXISTS search_text TEXT GENERATED ALWAYS AS (
    COALESCE(name, '') || ' ' || 
    COALESCE(chain, '')
) STORED;

-- Add a search_text column to theatres table that concatenates all searchable fields
ALTER TABLE theatres ADD COLUMN IF NOT EXISTS search_text TEXT GENERATED ALWAYS AS (
    COALESCE(name, '') || ' ' || 
    COALESCE(address, '') || ' ' ||
    COALESCE(website, '')
) STORED;

-- Function to search cinemas
CREATE OR REPLACE FUNCTION search_cinemas(search_query text)
RETURNS TABLE (
    id text,
    name text,
    location jsonb,
    address text,
    chain text,
    similarity float
) AS $$
WITH similarity_calc AS (
    SELECT 
        id,
        name,
        jsonb_build_object(
            'coordinates', ARRAY[
                ST_X(location::geometry),
                ST_Y(location::geometry)
            ]
        ) as location,
        address,
        chain,
        CASE 
            WHEN chain = 'odeon_gb' AND search_query ILIKE '%odeon%' THEN 
                similarity(name || ' ' || chain, search_query)
            ELSE 
                similarity(name, search_query)
        END as sim
    FROM cinemas
)
SELECT 
    similarity_calc.id,
    similarity_calc.name,
    similarity_calc.location,
    similarity_calc.address,
    similarity_calc.chain,
    similarity_calc.sim as similarity
FROM similarity_calc
WHERE sim > 0.3
ORDER BY sim DESC
LIMIT 1;
$$ LANGUAGE sql STABLE;

-- Function to search theatres
CREATE OR REPLACE FUNCTION search_theatres(search_query text)
RETURNS TABLE (
    place_id text,
    name text,
    location jsonb,
    address text,
    similarity double precision
) AS $$
BEGIN
    RETURN QUERY
    WITH similarity_calc AS (
        SELECT 
            t.place_id,
            t.name,
            jsonb_build_object(
                'coordinates', ARRAY[
                    ST_X(t.location::geometry),
                    ST_Y(t.location::geometry)
                ]
            ) as location,
            t.address,
            similarity(t.name, search_query) as name_sim,
            similarity(t.search_text, search_query) as text_sim,
            CASE 
                WHEN LOWER(t.name) = LOWER(search_query) THEN 1.0
                WHEN LOWER(t.name) LIKE LOWER('%' || search_query || '%') THEN 0.9
                ELSE similarity(t.search_text, search_query)
            END as match_sim
        FROM theatres t
        WHERE 
            t.search_text % search_query
            OR t.search_text ILIKE '%' || search_query || '%'
            OR t.name ILIKE '%' || search_query || '%'
    )
    SELECT 
        similarity_calc.place_id,
        similarity_calc.name,
        similarity_calc.location,
        similarity_calc.address,
        GREATEST(name_sim, text_sim, match_sim)::double precision as similarity
    FROM similarity_calc
    ORDER BY 
        CASE 
            WHEN LOWER(similarity_calc.name) = LOWER(search_query) THEN 1
            WHEN LOWER(similarity_calc.name) LIKE LOWER('%' || search_query || '%') THEN 2
            ELSE 3
        END,
        similarity DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Create indexes to speed up similarity searches
CREATE INDEX IF NOT EXISTS idx_cinemas_search_text_trgm ON cinemas USING gin(search_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_theatres_search_text_trgm ON theatres USING gin(search_text gin_trgm_ops);

-- Function to execute SQL commands
CREATE OR REPLACE FUNCTION exec_sql(sql text)
RETURNS void AS $$
BEGIN
    EXECUTE sql;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop all versions of the function first
DO $$ 
BEGIN
    DROP FUNCTION IF EXISTS filter_restaurants(text);
    DROP FUNCTION IF EXISTS filter_restaurants(text, text[]);
    DROP FUNCTION IF EXISTS filter_restaurants(text, jsonb);
    DROP FUNCTION IF EXISTS find_restaurants_near_venue(numeric, numeric, text[], text[], integer);
    DROP FUNCTION IF EXISTS find_restaurants_near_venue(double precision, double precision, text[], text[], integer);
EXCEPTION 
    WHEN others THEN 
        NULL;
END $$;

-- Function to safely execute restaurant search queries
CREATE OR REPLACE FUNCTION filter_restaurants(
    query_string text,
    params jsonb DEFAULT '[]'::jsonb
) RETURNS SETOF public.restaurants AS $$
DECLARE
    final_query text;
    error_message text;
BEGIN
    -- Validate that the query starts with SELECT and contains expected clauses
    IF NOT (
        query_string ILIKE 'SELECT%' AND
        query_string ILIKE '%FROM public.restaurants%'
    ) THEN
        error_message := 'Invalid query format: ' || query_string;
        RAISE EXCEPTION '%', error_message;
    END IF;

    -- Add PostGIS functions to the security barrier
    IF query_string ~* '(ST_DWithin|ST_Distance|ST_SetSRID|ST_MakePoint|ST_X|ST_Y|::geography|::geometry)' THEN
        -- Query uses PostGIS functions, which is allowed
        -- Ensure PostGIS extension is enabled
        BEGIN
            CREATE EXTENSION IF NOT EXISTS postgis;
        EXCEPTION WHEN OTHERS THEN
            error_message := 'Error enabling PostGIS: ' || SQLERRM;
            RAISE EXCEPTION '%', error_message;
        END;
    END IF;

    -- Log the query for debugging
    RAISE NOTICE 'Executing query: %', query_string;

    -- Execute the query directly
    RETURN QUERY EXECUTE query_string;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error details
        error_message := 'Error executing query: ' || SQLERRM || ' (SQLSTATE: ' || SQLSTATE || ')';
        RAISE EXCEPTION '%', error_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION filter_restaurants(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION filter_restaurants(text) TO authenticated;

-- Function to find a group by name case-insensitively
CREATE OR REPLACE FUNCTION find_group_by_name(search_name text)
RETURNS TABLE (
    id uuid,
    name text,
    member_ids uuid[],
    created_by uuid
) AS $$
BEGIN
    RETURN QUERY
    SELECT g.id, g.name, g.member_ids, g.created_by
    FROM public.groups g
    WHERE LOWER(g.name) = LOWER(search_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to find restaurants near a venue with various filters
CREATE OR REPLACE FUNCTION find_restaurants_near_venue(
    venue_lat double precision,
    venue_lon double precision,
    excluded_cuisines text[] DEFAULT NULL,
    cuisine_types text[] DEFAULT NULL,
    max_results integer DEFAULT 200
)
RETURNS TABLE (
    id text,
    name text,
    cuisine_type text,
    address text,
    rating double precision,
    price_level integer,
    latitude double precision,
    longitude double precision,
    distance double precision
) AS $$
BEGIN
    RETURN QUERY
    WITH base_query AS (
        SELECT 
            r."RestaurantID" as id,
            r."Name" as name,
            r."CuisineType" as cuisine_type,
            r."Address" as address,
            r."Rating" as rating,
            CAST(r."PriceLevel" AS integer) as price_level,
            r."latitude" as latitude,
            r."longitude" as longitude,
            ST_Distance(
                r.location::geography,
                ST_SetSRID(ST_MakePoint(venue_lon, venue_lat), 4326)::geography
            ) as distance
        FROM restaurants r
        WHERE 
            -- Excluded cuisines filter (case-insensitive)
            (excluded_cuisines IS NULL OR 
             NOT EXISTS (
                SELECT 1 FROM unnest(excluded_cuisines) ec 
                WHERE LOWER(r."CuisineType") = LOWER(ec)
             ))
            -- Cuisine types filter (case-insensitive)
            AND (cuisine_types IS NULL OR 
                 EXISTS (
                    SELECT 1 FROM unnest(cuisine_types) ct 
                    WHERE LOWER(r."CuisineType") = LOWER(ct)
                 ))
    )
    SELECT *
    FROM base_query
    ORDER BY distance ASC
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION find_restaurants_near_venue(double precision, double precision, text[], text[], integer) TO authenticated;

-- Function to get groups for a user
CREATE OR REPLACE FUNCTION get_user_groups(user_id_input uuid)
RETURNS TABLE (
    id uuid,
    name text,
    member_ids uuid[],
    created_by uuid
) AS $$
BEGIN
    RETURN QUERY
    SELECT g.id, g.name, g.member_ids, g.created_by
    FROM public.groups g
    WHERE user_id_input = ANY(g.member_ids)
    OR g.created_by = user_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION get_user_groups(uuid) TO authenticated;
