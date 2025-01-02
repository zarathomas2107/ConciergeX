import asyncio
import json
from dotenv import load_dotenv
from supabase import create_client
import os

# Load environment variables
load_dotenv()

async def test_sql_query():
    """Test running a SQL query directly against Supabase"""
    
    # Initialize Supabase client
    supabase = create_client(
        os.getenv("SUPABASE_URL"),
        os.getenv("SUPABASE_KEY")
    )
    
    # Test query
    query = """
    SELECT * FROM restaurants 
    WHERE ST_DWithin(
        ST_Point("Longitude", "Latitude"), 
        ST_Point(-0.1332442, 51.5114967), 
        1000
    ) 
    AND "CuisineType" = 'Italian' 
    ORDER BY "Rating" DESC 
    LIMIT 20
    """
    
    print("\n🔍 Testing SQL query:")
    print("-" * 80)
    print(query)
    print("-" * 80)
    
    try:
        # Execute query using RPC
        response = supabase.rpc(
            'filter_restaurants',
            {
                'query_string': query
            }
        ).execute()
        
        print("\n📝 Results:")
        if response.data:
            for restaurant in response.data:
                print(f"- {restaurant['Name']} ({restaurant['CuisineType']})")
                print(f"  Rating: {restaurant['Rating']}, Address: {restaurant['Address']}")
                print()
        else:
            print("No restaurants found")
            
        print(f"\nTotal results: {len(response.data) if response.data else 0}")
        
    except Exception as e:
        print(f"\n❌ Error executing query: {e}")

if __name__ == "__main__":
    asyncio.run(test_sql_query()) 