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

    except Exception as e:
        print(f"Error updating functions: {e}")

if __name__ == "__main__":
    update_functions() 