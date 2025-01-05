import logging
import requests
from typing import List, Dict
from dotenv import load_dotenv

from search_service.agents.llama_agent import LlamaAgent
from search_service.clients.supabase_client import SupabaseClient
from search_service.clients.google import GoogleClient

# Load environment variables and configure logging
load_dotenv()
logging.basicConfig(level=logging.INFO)

class LocationDetector:
    """Class for detecting and processing location information from queries."""
    
    SIMILARITY_THRESHOLD = 0.85
    TEST_QUERIES = [
        "Let's visit the British Museum in Soho",
        "I want to go to Tower Bridge and the Tower of London",
        "Looking for a cinema near Covent Garden",
        "Is there a good restaurant in Mayfair?",
        "Want to see Big Ben",
        "Resturants Near Kew Gardens"
    ]
    
    def __init__(self):
        """Initialize the LocationDetector with required clients."""
        try:
            self.supabase = SupabaseClient()
            self.google_client = GoogleClient()
            self.llama_agent = LlamaAgent()
            self.logger = logging.getLogger(__name__)
        except Exception as e:
            print(f"Error initializing LocationDetector: {str(e)}")
            raise

    def extract_terms(self, query: str) -> List[str]:
        """
        Extract landmark terms from a query using LlamaAgent.
        
        Args:
            query (str): The input query to extract landmarks from
            
        Returns:
            List[str]: List of extracted landmark terms
        """
        try:
            self.logger.info(f"Extracting landmarks from query: {query}")        
            
            # Define the system prompt for landmark extraction
            system_prompt = """
            You are a location extraction specialist. Extract all location-related names from user queries.

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

            Example:
            "Let's visit the British Museum in Soho" -> {"extracted_terms": ["British Museum", "Soho"]}
            "The Tower of London is near Tower Bridge" -> {"extracted_terms": ["Tower of London", "Tower Bridge"]}
            "Let's go to a cinema" -> {"extracted_terms": ["cinema"]}

            Always respond with valid JSON. Do not include any other text.
            """.strip()
            
            # Get completion from LlamaAgent - use synchronous version
            response = self.llama_agent.get_completion(
                query,
                system_prompt=system_prompt
            )
            # Process the response
            terms = response.get('extracted_terms', [])
            return terms
        
        except Exception as e:
            self.logger.error(f"Error extracting landmarks: {str(e)}")
            return []

    def get_embedding(self, text: str, model: str = "nomic-embed-text") -> list[float]:
        """Get embedding from Ollama"""
        try:
            response = requests.post(
                'http://localhost:11434/api/embeddings',
                json={"model": model, "prompt": text}
            )
            return response.json()["embedding"]
        except Exception as e:
            self.logger.error(f"Error getting embedding for text '{text}': {str(e)}")
            return None

    def query_similar_pois(self, embedding: List[float]) -> List[Dict]:
        """Query similar points of interest for the first extracted term.
        
        Args:
            embedding (List[float]): Embedding of the extracted landmark terms
            supabase_client (SupabaseClient): Initialized Supabase client
            
        Returns:
            List[Dict]: List of similar points of interest
        """
        try:
            self.logger.info(f"Querying similar POIs")
            
            # Query similar POIs using the embedding
            results = self.supabase.rpc(
                'search_similar_pois',
                params={
                    'query_embedding': embedding,
                    'limit_count': 1
                }
            )
            
            return results.data if hasattr(results, 'data') else []
        
        except Exception as e:
            self.logger.error(f"Error querying similar POIs: {str(e)}")
            return []

    def google_places_search(self, terms: List[str]) -> List[Dict]:
        
        """Search for places using Google Places API

        Args:
            terms (List[str]): List of search terms
            
        Returns:
            List[Dict]: List containing the most relevant place match
        """
        try:
            if not terms:
                self.logger.info("No terms provided to search")
                return []
            
            # Take only the first term
            first_term = terms[0]
            self.logger.info(f"Searching Google Places for term: {first_term}")
            
            # Search for places using the instance method
            places = self.google_client.places_search(first_term)
            if places:
                self.logger.info(f"Found place: {places[0].get('name')} at {places[0].get('address')}")
            else:
                self.logger.info("No places found")
                
            return places
        
        except Exception as e:
            self.logger.error(f"Error searching for places: {str(e)}")
            return []

    def detect_location(self, query: str) -> tuple[str, str, str]:
        """Detect and retrieve venue information from query.
        
        Args:
            query (str): Search query
            
        Returns:
            tuple[str, str, str]: Location ID, name, and location
        """
        # Extract and get embedding
        extracted_terms = self.extract_terms(query)
        embedding = self.get_embedding(extracted_terms[0])
        similar_pois = self.query_similar_pois(embedding)
        
        # Get POI data either from database or Google Places
        if similar_pois and (1 - similar_pois[0].get("similarity", 0)) >= self.SIMILARITY_THRESHOLD:
            # Use existing POI from database
            poi_data = similar_pois[0]
        else:
            # Search Google Places and store result
            google_result = self.google_places_search(extracted_terms)[0]
            poi_data = self.supabase.upsert_data_poi(
                google_result, 
                embedding, 
                "points_of_interest"
            ).get("data", [{}])[0]
        
        # Extract required fields
        return (
            poi_data.get("id", ""),
            poi_data.get("name", ""),
            poi_data.get("location", "")
        )

    @classmethod
    def get_test_queries(cls) -> List[str]:
        """Get the list of test queries."""
        return cls.TEST_QUERIES

# Example usage with better error handling
if __name__ == "__main__":
    try:
        detector = LocationDetector()
        
        for query in LocationDetector.TEST_QUERIES:  # Using class constant directly
            try:
                print(f"\nQuery: {query}")
                location_info = detector.detect_location(query)
                print(f"Location info: {location_info}")
            except Exception as e:
                print(f"Error processing query '{query}': {str(e)}")
                continue
                
    except Exception as e:
        print(f"Failed to initialize LocationDetector: {str(e)}")