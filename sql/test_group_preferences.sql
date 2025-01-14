-- Test the get_group_members_preferences function
-- Replace this with your actual user ID
SELECT * FROM get_group_members_preferences('a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1');

-- To see the raw data that feeds into the function, we can run:
WITH group_data AS (
    SELECT 
      g.id,
      g.name,
      g.created_by,
      g.member_ids
    FROM groups g
    WHERE g.member_ids @> ARRAY['a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1']::uuid[]
    OR g.created_by = 'a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1'::uuid
),
all_members AS (
    -- Combine creator and members into one list
    SELECT DISTINCT id
    FROM (
      SELECT unnest(gd.member_ids) as id
      FROM group_data gd
      UNION
      SELECT gd.created_by as id
      FROM group_data gd
    ) all_ids
)
SELECT 
    g.name as group_name,
    g.created_by,
    g.member_ids,
    p.id as member_id,
    p.first_name,
    p.last_name,
    p.dietary_requirements,
    p.excluded_cuisines
FROM group_data g
CROSS JOIN all_members am
JOIN profiles p ON p.id = am.id
ORDER BY g.name; 