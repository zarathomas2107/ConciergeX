-- Update group members preferences function to include creator and combine preferences
create or replace function get_group_members_preferences(user_id text)
returns json
language sql
as $$
  WITH group_data AS (
    SELECT 
      g.id,
      g.name,
      g.created_by,
      g.member_ids
    FROM groups g
    WHERE g.member_ids @> ARRAY[user_id]::uuid[]
    OR g.created_by = user_id::uuid
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
  ),
  member_preferences AS (
    SELECT 
      p.id,
      p.dietary_requirements,
      CASE 
        WHEN p.excluded_cuisines IS NULL OR p.excluded_cuisines = '[]' THEN '{}'::text[]
        ELSE (
          SELECT array_agg(DISTINCT initcap(trim(both '"' from cuisine)))
          FROM jsonb_array_elements_text(p.excluded_cuisines::jsonb) as cuisine
        )
      END as excluded_cuisines
    FROM profiles p
    JOIN all_members am ON p.id = am.id
  ),
  normalized_preferences AS (
    SELECT 
      gd.id as group_id,
      gd.name as group_name,
      array_agg(DISTINCT initcap(dr.requirement)) FILTER (WHERE dr.requirement IS NOT NULL) as all_dietary_requirements,
      array_agg(DISTINCT ec) FILTER (WHERE ec IS NOT NULL AND ec != '') as all_excluded_cuisines
    FROM group_data gd
    CROSS JOIN member_preferences mp
    LEFT JOIN LATERAL jsonb_array_elements_text(mp.dietary_requirements::jsonb) dr(requirement) ON true
    LEFT JOIN LATERAL unnest(mp.excluded_cuisines) ec ON true
    GROUP BY gd.id, gd.name
  )
  SELECT 
    json_agg(
      json_build_object(
        'id', group_id,
        'name', group_name,
        'preferences', json_build_object(
          'dietary_requirements', COALESCE(all_dietary_requirements, '{}'),
          'excluded_cuisines', COALESCE(all_excluded_cuisines, '{}')
        )
      )
    )
  FROM normalized_preferences;
$$; 