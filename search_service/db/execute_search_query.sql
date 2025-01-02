CREATE OR REPLACE FUNCTION execute_search_query(
  query_text TEXT,
  query_params JSONB DEFAULT '{}'::JSONB
)
RETURNS SETOF JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSON;
  safe_query TEXT;
BEGIN
  -- Validate that the query only accesses allowed tables
  IF NOT (
    query_text ~* '^[\s\n]*SELECT.*FROM[\s\n]+(restaurants|venues|restaurants_availability).*$'
    AND query_text !~* '(DELETE|DROP|UPDATE|INSERT|ALTER|CREATE|TRUNCATE|GRANT|REVOKE)'
  ) THEN
    RAISE EXCEPTION 'Invalid query: Only SELECT statements on approved tables are allowed';
  END IF;

  -- Execute the query with parameters
  EXECUTE format('SELECT row_to_json(t) FROM (%s) t', query_text)
  USING query_params
  INTO result;

  RETURN NEXT result;
END;
$$;