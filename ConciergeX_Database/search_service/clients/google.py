import os
import logging
import requests
from typing import Dict, List, Optional
from datetime import datetime
logger = logging.getLogger(__name__)



class GoogleClient:
    def __init__(self):
        self.api_key = os.getenv('GOOGLE_API_KEY')
        if not self.api_key:
            raise ValueError("Please set GOOGLE_API_KEY environment variable")
        
        
    def places_search(self, query: str, embedding: Optional[List[float]] = None) -> List[Dict]:
        """Search for places using the Google Places API.
        
        Args:
            query: The search query string
            embedding: Optional embedding vector to include in the results
            
        Returns:
            List[Dict]: List of places with their details
        """
        places_endpoint = "https://maps.googleapis.com/maps/api/place/textsearch/json"

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
            # Make the API Request
            response = requests.get(
                places_endpoint,
                params=params,
                headers=headers
            )
            response.raise_for_status()  # Raise exception for bad status codes
            
            # Process the response
            places = response.json().get('results', [])
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
                    'user_ratings_total': place.get('user_ratings_total'),
                    'embedding': embedding,
                    'created_at': datetime.now().isoformat(),
                    'updated_at': datetime.now().isoformat()
                }
                results.append(place_data)
            
            return results
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Error making Google Places API request: {str(e)}")
            return []
        except Exception as e:
            logger.error(f"Error processing Google Places response: {str(e)}")
            return []