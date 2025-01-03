import os
import logging
import requests
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

class GooglePlacesClient:
    def __init__(self):
        self.api_key = os.getenv('GOOGLE_API_KEY')
        if not self.api_key:
            raise ValueError("Please set GOOGLE_API_KEY environment variable")
        
        self.places_endpoint = "https://places.googleapis.com/v1/places:searchText"
        # Central London coordinates
        self.london_lat = 51.5074
        self.london_lng = -0.1278
    
    def search_places(self, query: str, lat: float = None, lng: float = None) -> List[Dict]:
        """Search for places using the Google Places API.
        
        Args:
            query: The search query string
            lat: Optional latitude of the search center
            lng: Optional longitude of the search center
        """
        try:
            # Use default coordinates for London if none provided
            lat = lat if lat is not None else self.london_lat
            lng = lng if lng is not None else self.london_lng
            
            # Construct the request body with location bias
            request_body = {
                "textQuery": str(query) if query is not None else "",
                "locationBias": {
                    "circle": {
                        "center": {
                            "latitude": lat,
                            "longitude": lng
                        },
                        "radius": 5000.0  # 5km radius
                    }
                }
            }
            
            logger.info(f"Making request to Google Places API with query: {query}")
            logger.info(f"Request body: {request_body}")
            
            # Make the API request
            headers = {
                "Content-Type": "application/json",
                "X-Goog-Api-Key": self.api_key,
                "X-Goog-FieldMask": "places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.types,places.websiteUri,places.nationalPhoneNumber"
            }
            
            logger.info(f"Request headers: {headers}")
            
            response = requests.post(
                self.places_endpoint,
                json=request_body,
                headers=headers
            )
            
            logger.info(f"Response status code: {response.status_code}")
            logger.info(f"Response headers: {response.headers}")
            logger.info(f"Response body: {response.text}")
            
            if response.status_code != 200:
                logger.error(f"Error from Google Places API: {response.text}")
                return []
            
            # Process the response
            data = response.json()
            places = data.get("places", [])
            
            # Convert the response to our format
            formatted_places = []
            for place in places:
                formatted_place = {
                    'id': place.get('id'),
                    'name': place.get('displayName', {}).get('text'),
                    'address': place.get('formattedAddress'),
                    'place_type': place.get('types', ['unknown'])[0],
                    'place_types': place.get('types', []),
                    'rating': place.get('rating'),
                    'user_ratings_total': place.get('userRatingCount'),
                    'latitude': place.get('location', {}).get('latitude'),
                    'longitude': place.get('location', {}).get('longitude'),
                    'website': place.get('websiteUri'),
                    'phone_number': place.get('nationalPhoneNumber')
                }
                formatted_places.append(formatted_place)
            
            logger.info(f"Found {len(formatted_places)} places")
            for place in formatted_places:
                logger.info(f"Place: {place['name']} at {place['address']}")
            
            return formatted_places
            
        except Exception as e:
            logger.error(f"Error searching Google Places: {e}")
            if hasattr(e, 'response'):
                logger.error(f"Response: {e.response.text if hasattr(e.response, 'text') else e.response}")
            return [] 