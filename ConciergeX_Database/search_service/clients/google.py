import os
from typing import List, Dict, Optional
import logging
from datetime import datetime
import aiohttp
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

logger = logging.getLogger(__name__)

class GoogleClient:
    """Client for interacting with Google APIs."""
    
    def __init__(self):
        """Initialize the GoogleClient with API key from environment variables."""
        self.api_key = os.getenv("GOOGLE_API_KEY")
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
            "query": query,
            "maxResultCount": 1,  # Number of results to return
            "key": self.api_key,
            "languageCode": "en",
            "locationBias": "circle:5000@51.5074,-0.1278"
        }

        # Headers
        headers = {
            "Content-Type": "application/json",
            "X-Goog-FieldMask": "places.displayName,places.formattedAddress,places.rating,places.location"
        }

        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    places_endpoint,
                    params=params,
                    headers=headers
                ) as response:
                    response.raise_for_status()
                    data = await response.json()
                    
                    # Process the response
                    places = data.get('results', [])
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
                        results.append(place_data)
                    
                    return results
                    
        except Exception as e:
            self.logger.error(f"Error searching for places: {str(e)}")
            return []