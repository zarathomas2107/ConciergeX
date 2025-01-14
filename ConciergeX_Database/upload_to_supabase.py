import pandas as pd
import asyncio
from search_service.clients.supabase_client import SupabaseClient

async def upload_restaurants():
    # Read the CSV file
    df = pd.read_csv('Data/restaurants_rows_updated.csv')
    
    # Initialize Supabase client
    client = SupabaseClient()
    
    # Convert DataFrame rows to list of dictionaries
    restaurants = df.to_dict('records')
    
    # Update each restaurant in Supabase
    for restaurant in restaurants:
        # Use the id as the condition for updating
        conditions = [('id', '=', restaurant['id'])]
        
        # Update the restaurant data
        result = await client.update_table(
            table_name='restaurants',
            data=restaurant,
            conditions=conditions
        )
        print(f"Updated restaurant: {restaurant['name']}")

if __name__ == "__main__":
    asyncio.run(upload_restaurants()) 