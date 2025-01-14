import os
from typing import List, Dict, Optional
import logging
from datetime import datetime
import aiohttp
from dotenv import load_dotenv, find_dotenv

# Load environment variables with override
load_dotenv(find_dotenv(), override=True)

logger = logging.getLogger(__name__)

class GoogleClient:
    """Client for interacting with Google APIs."""
    
    def __init__(self):
        """Initialize the GoogleClient with API key from environment variables."""
        # Force reload environment variables
        load_dotenv(find_dotenv(), override=True)
        self.logger = logging.getLogger(__name__)
        self.api_key = os.getenv("GOOGLE_API_KEY")
        self.logger.info("Initializing Google Client")
        self.logger.info(f"API Key found: {'Yes' if self.api_key else 'No'}")
        self.logger.info(f"API Key length: {len(self.api_key) if self.api_key else 0}")
        if not self.api_key:
            raise ValueError("GOOGLE_API_KEY must be set in environment variables")
            
    async def places_search_async(self, query: str | list, embedding: Optional[List[float]] = None) -> List[Dict]:
        """
        Search for places using the Google Places API asynchronously.
        
        Args:
            query: The search query string or list of terms
            embedding: Optional embedding vector to include in the results
            
        Returns:
            List[Dict]: List of places with their details
        """
        # Reload API key on each request to ensure we have the latest
        load_dotenv(find_dotenv(), override=True)
        self.api_key = os.getenv("GOOGLE_API_KEY")
        
        places_endpoint = "https://maps.googleapis.com/maps/api/place/textsearch/json"

        # Handle list input
        if isinstance(query, list):
            query = " ".join(query)
        elif isinstance(query, dict):
            # Extract location name from dictionary
            query = query.get('name', '') or query.get('location', '')
            
        if not query:
            self.logger.warning("Empty query provided")
            return []

        # Define Search Parameters
        params = {
            "query": f"{query}, London, UK",
            "key": self.api_key,
            "language": "en",
            "location": "51.5074,-0.1278",
            "radius": "20000"  # 20km radius
        }

        self.logger.info(f"Making Places API request to: {places_endpoint}")
        self.logger.info(f"Query parameters (excluding key): {dict((k,v) for k,v in params.items() if k != 'key')}")
        self.logger.info(f"Using API key starting with: {self.api_key[:10]}...")

        try:
            # Use a fresh session for each request
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    places_endpoint,
                    params=params,
                    headers={'Cache-Control': 'no-cache'}
                ) as response:
                    self.logger.info(f"Places API response status: {response.status}")
                    
                    if response.status != 200:
                        error_text = await response.text()
                        self.logger.error(f"Places API error response: {error_text}")
                        return []
                        
                    data = await response.json()
                    self.logger.info(f"Places API raw response: {data}")
                    self.logger.info(f"Places API response status: {data.get('status')}")
                    
                    if data.get('status') != 'OK':
                        self.logger.error(f"Places API error: {data.get('error_message', 'Unknown error')}")
                        return []
                    
                    # Process the response
                    places = data.get('results', [])
                    self.logger.info(f"Found {len(places)} places in response")
                    
                    # Format the results 
                    results = []
                    for place in places:
                        place_data = {
                            'business_status': place.get('business_status'),
                            'name': place.get('name'),
                            'id': place.get('place_id'),
                            'formatted_address': place.get('formatted_address'),
                            'latitude': place.get('geometry', {}).get('location', {}).get('lat'),
                            'longitude': place.get('geometry', {}).get('location', {}).get('lng'),
                            'rating': place.get('rating'),
                            'types': place.get('types', []),
                            'created_at': datetime.now().isoformat(),
                            'updated_at': datetime.now().isoformat()
                        }
                        
                        self.logger.info(f"Found place: {place_data['name']} at {place_data['formatted_address']}")
                        results.append(place_data)
                    
                    return results
                    
        except aiohttp.ClientError as e:
            self.logger.error(f"HTTP error during Places API request: {str(e)}")
            return []
        except Exception as e:
            self.logger.error(f"Unexpected error during Places API request: {str(e)}")
            return []