import os
from dotenv import load_dotenv
from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions
import uuid

# Load environment variables
load_dotenv()

# Verify environment variables
required_vars = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY']
for var in required_vars:
    if not os.getenv(var):
        raise EnvironmentError(f"Missing required environment variable: {var}")

# Initialize Supabase client with service role key
supabase: Client = create_client(
    os.getenv("SUPABASE_URL", ""),
    os.getenv("SUPABASE_SERVICE_KEY", "")
)

def setup_test_data():
    try:
        # Insert test user profile
        user_data = {
            'id': '7ccda55d-7dc6-4359-b873-c5de9fa8ffdf',
            'dietary_requirements': ['vegetarian', 'halal'],
            'excluded_cuisines': ['seafood'],
            'restaurant_preferences': ['italian', 'indian']
        }
        result = supabase.table('profiles').upsert(user_data).execute()
        print(f"Inserted test user profile: {result}")

        # Insert test groups
        groups_data = [
            {
                'id': str(uuid.uuid4()),
                'name': 'family',
                'member_ids': ['7ccda55d-7dc6-4359-b873-c5de9fa8ffdf']
            },
            {
                'id': str(uuid.uuid4()),
                'name': 'friends',
                'member_ids': ['7ccda55d-7dc6-4359-b873-c5de9fa8ffdf']
            },
            {
                'id': str(uuid.uuid4()),
                'name': 'colleagues',
                'member_ids': ['7ccda55d-7dc6-4359-b873-c5de9fa8ffdf']
            }
        ]
        for group in groups_data:
            result = supabase.table('groups').upsert(group).execute()
            print(f"Inserted test group: {result}")

    except Exception as e:
        print(f"Error setting up test data: {e}")

if __name__ == "__main__":
    setup_test_data() 