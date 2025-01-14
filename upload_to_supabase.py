import pandas as pd
import asyncio
import httpx
import os
from dotenv import load_dotenv
import logging
import numpy as np
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

def clean_restaurant_data(restaurant):
    """Clean and validate restaurant data before sending to Supabase."""
    # Create a copy to avoid modifying the original
    cleaned = restaurant.copy()
    
    # Convert price_level to integer if it exists and is not empty
    if 'price_level' in cleaned and cleaned['price_level'] != '':
        try:
            cleaned['price_level'] = int(float(cleaned['price_level']))
        except (ValueError, TypeError):
            del cleaned['price_level']
    else:
        del cleaned['price_level']
    
    # Handle NaN values in all fields
    for key in list(cleaned.keys()):
        if pd.isna(cleaned[key]) or cleaned[key] == 'NaN':
            del cleaned[key]
        elif isinstance(cleaned[key], float) and key not in ['rating', 'latitude', 'longitude']:
            # Convert non-coordinate/rating floats to integers
            cleaned[key] = int(cleaned[key])
    
    return cleaned

async def upload_restaurants():
    # Get Supabase credentials
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_ANON_KEY")
    
    if not url or not key:
        raise ValueError("Missing Supabase credentials")
    
    # Read the CSV file
    df = pd.read_csv('Data/restaurants_rows_updated.csv')
    
    # Print column names and first row for debugging
    logger.info(f"Columns in CSV: {df.columns.tolist()}")
    logger.info(f"First row: {df.iloc[0].to_dict()}")
    
    # Convert DataFrame rows to list of dictionaries
    restaurants = df.to_dict('records')
    
    success_count = 0
    error_count = 0
    
    # Update each restaurant in Supabase
    async with httpx.AsyncClient() as client:
        for restaurant in restaurants:
            try:
                # Clean the data before sending
                cleaned_data = clean_restaurant_data(restaurant)
                restaurant_id = cleaned_data.pop('id', None)  # Remove id from the data to update
                
                if not restaurant_id:
                    logger.error(f"Missing ID for restaurant {cleaned_data.get('name', 'Unknown')}")
                    error_count += 1
                    continue

                # Print request details for debugging
                logger.info(f"Request details:")
                logger.info(f"URL: {url}/rest/v1/restaurants")
                logger.info(f"Params: {{'id': 'eq.{restaurant_id}'}}")
                logger.info(f"Data: {json.dumps(cleaned_data, indent=2)}")

                # Make the PATCH request with proper ID filter using eq operator
                response = await client.patch(
                    f"{url}/rest/v1/restaurants",
                    params={"id": f"eq.{restaurant_id}"},  # Using eq operator for exact match
                    json=cleaned_data,
                    headers={
                        "apikey": key,
                        "Authorization": f"Bearer {key}",
                        "Content-Type": "application/json",
                        "Prefer": "return=representation"
                    }
                )
                
                # Print response details for debugging
                logger.info(f"Response status: {response.status_code}")
                logger.info(f"Response headers: {dict(response.headers)}")
                logger.info(f"Response body: {response.text}")
                
                response.raise_for_status()
                logger.info(f"Updated restaurant: {cleaned_data.get('name', 'Unknown')}")
                success_count += 1
                
            except Exception as e:
                error_count += 1
                logger.error(f"Error updating restaurant {restaurant.get('name', 'Unknown')}: {str(e)}")
                continue
    
    logger.info(f"Update complete. Successes: {success_count}, Errors: {error_count}")

if __name__ == "__main__":
    asyncio.run(upload_restaurants()) 