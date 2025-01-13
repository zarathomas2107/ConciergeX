import os
import logging
import aiohttp
import asyncio
from typing import List, Dict
from dotenv import load_dotenv
from datetime import datetime, timezone
import googlemaps
from supabase import create_client, Client

# Load environment variables and configure logging
load_dotenv()
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

class RestaurantUpdater:
    """Class for updating restaurant information using Google Places API."""
    
    def __init__(self):
        """Initialize the RestaurantUpdater with required clients."""
        try:
            self.logger = logging.getLogger(__name__)
            self.logger.info("Initializing RestaurantUpdater")
            
            # Initialize Google Maps client
            self.gmaps = googlemaps.Client(key=os.environ.get('GOOGLE_API_KEY'))
            
            # Initialize Supabase client
            supabase_url = os.environ.get('SUPABASE_URL')
            supabase_key = os.environ.get('SUPABASE_KEY')
            self.supabase: Client = create_client(supabase_url, supabase_key)
            
            self.logger.info("RestaurantUpdater initialized successfully")
        except Exception as e:
            self.logger.error(f"Failed to initialize RestaurantUpdater: {str(e)}")
            raise

    def search_restaurants(self, query: str) -> List[Dict]:
        """Search for restaurants using Google Places API."""
        try:
            self.logger.info(f"Searching for restaurants with query: {query}")
            
            # Search for places
            places_result = self.gmaps.places(
                query=query,
                type='restaurant',
                location=(51.5074, -0.1278),  # London coordinates
                radius=50000  # 50km radius
            )
            
            restaurants = []
            for place in places_result.get('results', []):
                # Get detailed place information
                place_details = self.gmaps.place(place['place_id'])['result']
                
                restaurant = {
                    'id': place['place_id'],
                    'name': place.get('name', ''),
                    'cuisine_type': self._get_cuisine_type(place_details),
                    'country': 'UK',
                    'city': 'London',
                    'address': place.get('formatted_address', ''),
                    'rating': place.get('rating', 0),
                    'business_status': place.get('business_status', ''),
                    'latitude': place['geometry']['location']['lat'],
                    'longitude': place['geometry']['location']['lng'],
                    'price_level': place.get('price_level', -1),
                    'website': place_details.get('website', ''),
                    'created_at': datetime.now(timezone.utc).isoformat(),
                    'updated_at': datetime.now(timezone.utc).isoformat(),
                    'location': f"POINT({place['geometry']['location']['lng']} {place['geometry']['location']['lat']})"
                }
                restaurants.append(restaurant)
            
            return restaurants
            
        except Exception as e:
            self.logger.error(f"Error searching restaurants: {str(e)}")
            return []

    def _get_cuisine_type(self, place_details: Dict) -> str:
        """Extract cuisine type from place details."""
        try:
            # Try to get cuisine from types first
            types = place_details.get('types', [])
            cuisine_types = [t for t in types if 'cuisine' in t]
            if cuisine_types:
                return cuisine_types[0].replace('_cuisine', '').title()
            
            # Try to get from categories if available
            categories = place_details.get('categories', [])
            if categories:
                return categories[0].title()
            
            return ''
        except Exception as e:
            self.logger.error(f"Error getting cuisine type: {str(e)}")
            return ''

    async def update_database(self, restaurants: List[Dict]) -> None:
        """Update the restaurants table in Supabase."""
        try:
            self.logger.info(f"Updating database with {len(restaurants)} restaurants")
            
            for restaurant in restaurants:
                # Upsert restaurant data
                result = self.supabase.table('restaurants').upsert(restaurant).execute()
                
                if result.data:
                    self.logger.info(f"Successfully updated restaurant: {restaurant['name']}")
                else:
                    self.logger.warning(f"Failed to update restaurant: {restaurant['name']}")
                    
        except Exception as e:
            self.logger.error(f"Error updating database: {str(e)}")

async def main():
    try:
        updater = RestaurantUpdater()
        
        # Get search query from command line
        query = input("Enter restaurant or location to search: ")
        
        # Search for restaurants
        restaurants = updater.search_restaurants(query)
        
        if restaurants:
            # Update database
            await updater.update_database(restaurants)
            print(f"Successfully processed {len(restaurants)} restaurants")
        else:
            print("No restaurants found")
            
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    asyncio.run(main()) 