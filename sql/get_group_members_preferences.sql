CREATE OR REPLACE FUNCTION public.get_group_members_preferences(
    group_name text,
    user_id uuid
)
RETURNS TABLE (
    dietary_requirements text[],
    excluded_cuisines text[]
) AS $$
BEGIN
    RETURN QUERY
    WITH group_data AS (
        SELECT g.member_ids, g.created_by
        FROM groups g
        WHERE g.name = group_name
        AND (g.created_by = user_id OR user_id = ANY(member_ids))
        LIMIT 1
    )
    SELECT 
        array_agg(DISTINCT dr) FILTER (WHERE dr IS NOT NULL) as dietary_requirements,
        array_agg(DISTINCT ec) FILTER (WHERE ec IS NOT NULL) as excluded_cuisines
    FROM (
        SELECT 
            jsonb_array_elements_text(p.dietary_requirements) as dr,
            jsonb_array_elements_text(p.excluded_cuisines) as ec
        FROM group_data gd
        CROSS JOIN profiles p
        WHERE p.id = ANY(gd.member_ids) OR p.id = gd.created_by
    ) x;
END;
$$ LANGUAGE plpgsql;

-- Example test query:
-- SELECT * FROM get_group_members_preferences('Jim', 'a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1'); 