from supabase import create_client
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Supabase client
supabase_url = os.environ.get('SUPABASE_URL')
supabase_key = os.environ.get('SUPABASE_KEY')
supabase = create_client(supabase_url, supabase_key)

# Main London areas and their coordinates
london_areas = [
    {
        "name": "Covent Garden",
        "latitude": 51.5117,
        "longitude": -0.1240,
        "description": "Major entertainment and shopping district",
        "area_type": "Central"
    },
    {
        "name": "Soho",
        "latitude": 51.5137,
        "longitude": -0.1337,
        "description": "Entertainment district known for restaurants and nightlife",
        "area_type": "Central"
    },
    {
        "name": "Mayfair",
        "latitude": 51.5100,
        "longitude": -0.1500,
        "description": "Upscale area known for luxury shops and restaurants",
        "area_type": "Central"
    },
    {
        "name": "Camden",
        "latitude": 51.5390,
        "longitude": -0.1426,
        "description": "Known for its markets and alternative culture",
        "area_type": "North"
    },
    {
        "name": "Shoreditch",
        "latitude": 51.5229,
        "longitude": -0.0777,
        "description": "Trendy area with art galleries and dining",
        "area_type": "East"
    },
    {
        "name": "South Bank",
        "latitude": 51.5050,
        "longitude": -0.1165,
        "description": "Cultural district along the Thames",
        "area_type": "South"
    },
    {
        "name": "Notting Hill",
        "latitude": 51.5090,
        "longitude": -0.1960,
        "description": "Fashionable area known for Portobello Road Market",
        "area_type": "West"
    },
    {
        "name": "Knightsbridge",
        "latitude": 51.5015,
        "longitude": -0.1607,
        "description": "Luxury shopping district",
        "area_type": "Central"
    },
    {
        "name": "Chelsea",
        "latitude": 51.4875,
        "longitude": -0.1687,
        "description": "Affluent area with high-end shopping",
        "area_type": "West"
    },
    {
        "name": "Piccadilly Circus",
        "latitude": 51.5100,
        "longitude": -0.1359,
        "description": "Major traffic junction and tourist attraction",
        "area_type": "Central"
    },
    {
        "name": "Leicester Square",
        "latitude": 51.5110,
        "longitude": -0.1281,
        "description": "Entertainment hub with cinemas and theatres",
        "area_type": "Central"
    },
    {
        "name": "Chinatown",
        "latitude": 51.5118,
        "longitude": -0.1283,
        "description": "Chinese community and restaurants",
        "area_type": "Central"
    },
    {
        "name": "Lyceum Theatre",
        "latitude": 51.5115,
        "longitude": -0.1200,
        "description": "Historic West End theatre",
        "area_type": "Central"
    },
    {
        "name": "Oxford Circus",
        "latitude": 51.5152,
        "longitude": -0.1418,
        "description": "Major shopping district",
        "area_type": "Central"
    },
    {
        "name": "Marylebone",
        "latitude": 51.5200,
        "longitude": -0.1505,
        "description": "Upscale residential and shopping area",
        "area_type": "Central"
    },
    {
        "name": "Fitzrovia",
        "latitude": 51.5207,
        "longitude": -0.1398,
        "description": "Mix of business and entertainment",
        "area_type": "Central"
    },
    {
        "name": "Holborn",
        "latitude": 51.5175,
        "longitude": -0.1200,
        "description": "Business and legal district",
        "area_type": "Central"
    }
]

def create_london_areas_table():
    # SQL to create the table using Supabase's REST API
    try:
        # Try to select from the table to check if it exists
        supabase.table('london_areas').select('*').execute()
        print("Table already exists")
    except Exception as e:
        if 'relation "public.london_areas" does not exist' in str(e):
            # Create the table using Supabase's SQL editor
            print("Table doesn't exist, creating it...")
            
            # You'll need to create the table manually in Supabase's SQL editor first
            # Copy this SQL and run it in the Supabase SQL editor:
            print("""
            CREATE TABLE IF NOT EXISTS public.london_areas (
                id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
                name TEXT UNIQUE NOT NULL,
                latitude DOUBLE PRECISION NOT NULL,
                longitude DOUBLE PRECISION NOT NULL,
                description TEXT,
                area_type TEXT NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
            );
            """)
            print("\nPlease create the table in Supabase SQL editor first, then run this script again.")
            exit(1)
        else:
            raise e

def populate_areas():
    try:
        # Clear existing data
        supabase.table('london_areas').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()
        print("Cleared existing data")
        
        # Insert all areas
        for area in london_areas:
            response = supabase.table('london_areas').insert(area).execute()
            print(f"Added {area['name']}")
            
        print("Successfully populated london_areas table")
    except Exception as e:
        print(f"Error populating areas: {e}")

if __name__ == "__main__":
    create_london_areas_table()
    populate_areas()