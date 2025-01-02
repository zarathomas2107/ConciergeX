-- Insert test user profile
INSERT INTO profiles (id, dietary_requirements, excluded_cuisines, restaurant_preferences)
VALUES (
    '7ccda55d-7dc6-4359-b873-c5de9fa8ffdf',
    '{"vegetarian", "halal"}',
    '{"seafood"}',
    '{"italian", "indian"}'
)
ON CONFLICT (id) DO UPDATE SET
    dietary_requirements = EXCLUDED.dietary_requirements,
    excluded_cuisines = EXCLUDED.excluded_cuisines,
    restaurant_preferences = EXCLUDED.restaurant_preferences;

-- Insert test groups
INSERT INTO groups (id, name, member_ids)
VALUES 
    ('test-family-group', 'family', ARRAY['7ccda55d-7dc6-4359-b873-c5de9fa8ffdf']),
    ('test-friends-group', 'friends', ARRAY['7ccda55d-7dc6-4359-b873-c5de9fa8ffdf']),
    ('test-colleagues-group', 'colleagues', ARRAY['7ccda55d-7dc6-4359-b873-c5de9fa8ffdf'])
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    member_ids = EXCLUDED.member_ids; 