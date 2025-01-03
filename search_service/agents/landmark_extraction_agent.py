import json
import logging
from typing import Dict, Any, List
from .llama_agent import LlamaAgent
from ..clients.google_places import GooglePlacesClient
from ..clients.supabase import SupabaseClient
import requests
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_embedding(text: str, model: str = "nomic-embed-text") -> list[float]:
    """Get embedding from our FastAPI service"""
    try:
        print(f"\n🔄 Getting embedding for: {text}")
        response = requests.post(
            'http://localhost:8000/embeddings',
            json={"text": text, "model": model}
        )
        print(f"📡 Embedding API response status: {response.status_code}")
        if response.status_code == 200:
            return response.json()["embedding"]
        print(f"❌ Failed to get embedding: {response.text}")
        return None
    except Exception as e:
        print(f"❌ Error getting embedding: {str(e)}")
        return None

class LandmarkExtractionAgent(LlamaAgent):
    def __init__(self, google_places_client: GooglePlacesClient, supabase_client: SupabaseClient):
        super().__init__(model_size="8b")
        self.google_places_client = google_places_client
        self.supabase_client = supabase_client

    async def extract_terms(self, query: str) -> Dict[str, List[str]]:
        """
        Extract all location terms from a query using Llama.
        """
        try:
            system_prompt = """You are a location extraction specialist. Extract all location-related names from user queries.

Format your response as a valid JSON object with this field:
{
    "extracted_terms": ["array of strings, each string being a location, landmark, venue, or area name that was explicitly mentioned"]
}

IMPORTANT RULES:
1. ONLY extract places that are EXPLICITLY mentioned
2. Extract ANY type of location-related terms:
   - Landmarks: "The British Museum", "Tower Bridge", "Big Ben"
   - Venues: "Odeon Leicester Square", "Apollo Theatre"
   - Areas: "Soho", "Covent Garden"
   - Generic venues: "cinema", "theatre", "museum"
3. Return the exact names as mentioned
4. Return an empty array if no locations mentioned
5. Do NOT extract parts of venue names (e.g., for "Odeon Leicester Square" do not also extract "Leicester Square")

Example:
"Let's visit the British Museum in Soho" -> {"extracted_terms": ["British Museum", "Soho"]}
"The Tower of London is near Tower Bridge" -> {"extracted_terms": ["Tower of London", "Tower Bridge"]}
"Let's go to a cinema" -> {"extracted_terms": ["cinema"]}
"Let's go to the Odeon Leicester Square" -> {"extracted_terms": ["Odeon Leicester Square"]}

Always respond with valid JSON. Do not include any other text."""

            result = await self._generate_response(query, system_prompt)
            logger.info(f"Llama extraction result: {result}")

            return {
                "extracted_terms": result.get('extracted_terms', [])
            }

        except Exception as e:
            logger.error(f"Error in term extraction: {e}")
            return {
                "extracted_terms": []
            }

    async def search_and_enrich_terms(self, query: str, lat: float = 51.5074, lng: float = -0.1278) -> List[Dict]:
        """
        Search for and enrich extracted terms with venue information using vector search.
        Returns a list of dictionaries in the format:
        {
            "venue_name": string, exact name of the venue,
            "confidence": number between 0 and 1,
            "location": string, coordinates in format "lat,lng"
        }
        """
        # Extract terms from the query
        extraction_result = await self.extract_terms(query)
        terms = extraction_result.get('extracted_terms', [])
        
        # Search for each term
        results = []
        for term in terms:
            # Generate embedding for the search term
            embedding = get_embedding(term)
            if not embedding:
                logger.error(f"Failed to generate embedding for term: {term}")
                continue
            
            # Search using vector similarity
            params = {
                'search_term': term,
                'search_embedding': embedding,
                'center_lat': lat,
                'center_lon': lng,
                'search_radius': 5000,
                'match_threshold': 0.7,
                'match_count': 1
            }
            
            logger.info(f"Searching for term: {term} at coordinates: ({lat}, {lng})")
            
            db_response = self.supabase_client.rpc(
                'vector_search_points_of_interest',
                params
            )
            
            venue = None
            db_results = db_response.data if db_response else []
            
            if db_results and len(db_results) > 0:
                db_venue = db_results[0]
                venue = {
                    'venue_name': db_venue['name'],
                    'confidence': db_venue['similarity'],
                    'location': f"{db_venue['latitude']},{db_venue['longitude']}"
                }
            else:
                # Fallback to Google Places
                google_results = self.google_places_client.search_places(term, lat=lat, lng=lng)
                if google_results:
                    google_venue = google_results[0]
                    venue = {
                        'venue_name': google_venue['name'],
                        'confidence': 0.8,  # Default confidence for Google Places results
                        'location': f"{google_venue['latitude']},{google_venue['longitude']}"
                    }
                    
                    # Save to database for future use
                    try:
                        self.supabase_client.rpc(
                            'upsert_point_of_interest',
                            {
                                'poi': {
                                    'id': google_venue['id'],
                                    'name': google_venue['name'],
                                    'address': google_venue['address'],
                                    'place_type': google_venue['place_types'][0] if google_venue['place_types'] else 'point_of_interest',
                                    'place_types': google_venue['place_types'],
                                    'rating': google_venue['rating'],
                                    'user_ratings_total': google_venue.get('user_ratings_total'),
                                    'latitude': google_venue['latitude'],
                                    'longitude': google_venue['longitude'],
                                    'website': google_venue.get('website'),
                                    'phone_number': google_venue.get('phone_number'),
                                    'language_code': 'en',
                                    'search_count': 1,
                                    'last_searched_at': datetime.now().isoformat()
                                }
                            }
                        )
                    except Exception as e:
                        logger.error(f"Failed to upsert venue to database: {str(e)}")
                        # Continue since we still want to return the venue even if upsert fails
            
            if venue:
                results.append(venue)
        
        return results 