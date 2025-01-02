import os
from supabase import create_client, Client
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables from parent directory
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(env_path)

# Verify required environment variables
required_vars = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY']
missing_vars = [var for var in required_vars if not os.getenv(var)]
if missing_vars:
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

# Initialize Supabase client
supabase = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_KEY")  # Use service key for admin operations
)

# SQL function definitions
search_cinemas_sql = '''
CREATE OR REPLACE FUNCTION search_cinemas(search_query text)
RETURNS TABLE (
    id text,
    name text,
    location jsonb,
    address text,
    chain text,
    similarity double precision
) AS $$
BEGIN
    RETURN QUERY
    WITH similarity_calc AS (
        SELECT 
            c.id::text,
            c.name,
            jsonb_build_object(
                'coordinates', ARRAY[
                    ST_X(c.location::geometry),
                    ST_Y(c.location::geometry)
                ]
            ) as location,
            c.address,
            c.chain,
            similarity(c.name, search_query) as name_sim,
            CASE 
                WHEN c.chain = 'odeon_gb' AND c.name ILIKE '%leicester square%' AND search_query ILIKE '%odeon%leicester%square%' THEN 1.0
                WHEN c.chain = 'odeon_gb' AND c.name ILIKE '%leicester square%' AND search_query ILIKE '%leicester%square%' THEN 0.9
                ELSE similarity(c.name, search_query)
            END::double precision as similarity
        FROM cinemas c
        WHERE 
            c.name % search_query
            OR c.name ILIKE '%' || search_query || '%'
            OR (c.chain = 'odeon_gb' AND c.name ILIKE '%leicester square%' AND 
                (search_query ILIKE '%odeon%leicester%square%' OR search_query ILIKE '%leicester%square%'))
    )
    SELECT 
        similarity_calc.id,
        similarity_calc.name,
        similarity_calc.location,
        similarity_calc.address,
        similarity_calc.chain,
        similarity_calc.similarity
    FROM similarity_calc
    ORDER BY 
        CASE 
            WHEN similarity_calc.chain = 'odeon_gb' AND search_query ILIKE '%odeon%' THEN 0
            ELSE 1
        END,
        similarity_calc.similarity DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;
'''

search_theatres_sql = '''
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
        similarity(t.name, search_query)::double precision as similarity
    FROM theatres t
    WHERE 
        t.name % search_query
        OR t.name ILIKE '%' || search_query || '%'
    ORDER BY similarity DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;
'''

filter_restaurants_sql = '''
-- Drop all versions of the function first
DO $$ 
BEGIN
    DROP FUNCTION IF EXISTS filter_restaurants(text);
    DROP FUNCTION IF EXISTS filter_restaurants(text, text[]);
    DROP FUNCTION IF EXISTS filter_restaurants(text, jsonb);
EXCEPTION 
    WHEN others THEN 
        NULL;
END $$;

-- Function to safely execute restaurant search queries with parameters
CREATE OR REPLACE FUNCTION filter_restaurants(
    query_string text,
    params jsonb DEFAULT '[]'::jsonb
) RETURNS SETOF restaurants AS $$
DECLARE
    final_query text;
    param_array text[];
BEGIN
    -- Validate that the query starts with SELECT and contains expected clauses
    IF NOT (
        query_string ILIKE 'SELECT%' AND
        query_string ILIKE '%FROM restaurants%' AND
        query_string ILIKE '%LIMIT%'
    ) THEN
        RETURN;
    END IF;

    -- Convert jsonb array to text array
    param_array := ARRAY(
        SELECT json_array_elements_text(params)
    );

    -- Replace parameter placeholders with array elements
    final_query := query_string;
    FOR i IN 1..array_length(param_array, 1) LOOP
        final_query := replace(final_query, '$' || i::text, quote_literal(param_array[i]));
    END LOOP;

    -- Execute the query
    RETURN QUERY EXECUTE final_query;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return empty result
        RAISE NOTICE 'Error executing query: %', SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
'''

find_restaurants_near_venue_sql = '''
-- Drop all versions of the function first
DO $$ 
BEGIN
    DROP FUNCTION IF EXISTS find_restaurants_near_venue(numeric, numeric, text[], text[], integer);
    DROP FUNCTION IF EXISTS find_restaurants_near_venue(double precision, double precision, text[], text[], integer);
EXCEPTION 
    WHEN others THEN 
        NULL;
END $$;

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
'''

get_user_groups_sql = '''
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
'''

def update_functions():
    try:
        # Update search_cinemas function
        result = supabase.rpc('exec_sql', {'sql': search_cinemas_sql}).execute()
        print("Updated search_cinemas function:", result)

        # Update search_theatres function
        result = supabase.rpc('exec_sql', {'sql': search_theatres_sql}).execute()
        print("Updated search_theatres function:", result)

        # Update filter_restaurants function
        result = supabase.rpc('exec_sql', {'sql': filter_restaurants_sql}).execute()
        print("Updated filter_restaurants function:", result)

        # Update find_restaurants_near_venue function
        result = supabase.rpc('exec_sql', {'sql': find_restaurants_near_venue_sql}).execute()
        print("Updated find_restaurants_near_venue function:", result)

        # Update get_user_groups function
        result = supabase.rpc('exec_sql', {'sql': get_user_groups_sql}).execute()
        print("Updated get_user_groups function:", result)

    except Exception as e:
        print(f"Error updating functions: {e}")

if __name__ == "__main__":
    update_functions() 