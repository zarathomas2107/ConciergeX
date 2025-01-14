import os
import sys
import json
from typing import Dict, Any, List, Optional

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import logging
import aiohttp
from dotenv import load_dotenv

from clients.openai_client import OpenAIClient
from clients.supabase_client import SupabaseClient
from clients.google import GoogleClient

# Load environment variables and configure logging
load_dotenv()
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

class LocationDetectionAgent:
    """Class for detecting and processing location information from queries."""
    
    SIMILARITY_THRESHOLD = 0.15
    TEST_QUERIES = [
        "Italian restaurant near Databricks office in London  with @family in February for Dinner",
        "Chinese restaurants near the Excel in London",
        "Burger restaurants near the O2 Arena"
    ]
    
    def __init__(self):
        """Initialize the LocationDetectionAgent with required clients."""
        try:
            self.logger = logging.getLogger(__name__)
            self.logger.info("Initializing LocationDetectionAgent")
            self.supabase = SupabaseClient()
            self.google_client = GoogleClient()
            self.openai_client = OpenAIClient()
            self.logger.info("LocationDetectionAgent initialized successfully")
        except Exception as e:
            self.logger.error(f"Failed to initialize LocationDetectionAgent: {str(e)}")
            raise

    async def extract_terms(self, query: str) -> List[str]:
        """Extract location terms from a query."""
        try:
            self.logger.info(f"Starting location term extraction for query: '{query}'")
            
            # System prompt for location extraction
            system_prompt = """
                You are a location extraction assistant specialized in London locations. Extract ONLY explicit location terms from queries.

                IMPORTANT: You MUST detect and return any mentions of these London areas and regions:

                Central London:
                - Westminster, Covent Garden, Soho, Mayfair, Bloomsbury, Fitzrovia, Holborn, St. James's, South Bank

                North London:
                - Camden, Islington, Hampstead, Highgate, Finchley, Muswell Hill, Finsbury Park

                East London:
                - Shoreditch, Hackney, Stratford, Canary Wharf, Bethnal Green, Bow, Walthamstow

                South London:
                - Brixton, Clapham, Greenwich, Dulwich, Wimbledon, Croydon, Peckham, Elephant and Castle

                West London:
                - Kensington, Chelsea, Notting Hill, Hammersmith, Fulham, Ealing, Chiswick, Richmond

                Greater London Suburbs:
                - Harrow, Bromley, Enfield, Kingston upon Thames, Hounslow, Barnet, Ilford

                Additionally, detect and return:
                1. Famous landmarks (e.g., "Big Ben", "Tower Bridge", "British Museum", "London Eye")
                2. Streets (e.g., "Oxford Street", "Piccadilly", "Bond Street")
                3. Stations (e.g., "Oxford Circus", "Waterloo", "King's Cross")
                4. Office buildings and company locations (e.g., "Databricks office", "Google HQ", "Amazon office")
                5. The city "London" when explicitly mentioned

                Rules:
                1. Return ONLY explicit location mentions
                2. Don't infer or guess locations - only return what's explicitly stated
                3. Return an empty list if NO locations are found
                4. Format as a JSON array of strings
                5. Generic terms like "restaurant", "cinema", "park" are NOT locations unless combined with specific locations
                6. DO include company offices when mentioned (e.g., "Databricks office", "Google office")
                7. When a company office is mentioned, include both the company name with "office" and the city if specified

                Examples:
                Input: "Looking for Italian food in Hackney"
                Output: ["Hackney"]

                Input: "Restaurant near Databricks office in Shoreditch"
                Output: ["Databricks office", "Shoreditch"]

                Input: "Dinner in Mayfair near Bond Street"
                Output: ["Mayfair", "Bond Street"]

                Input: "Places to eat in Canary Wharf"
                Output: ["Canary Wharf"]

                Input: "Restaurant with @Family"
                Output: []

                Input: "Looking for a cinema in Stratford near Westfield"
                Output: ["Stratford", "Westfield"]
            """.strip()
            
            # Get completion from OpenAI
            self.logger.debug("Sending query to OpenAI for location extraction")
            response = await self.openai_client.get_completion(query, system_prompt=system_prompt)
            
            if not response:
                self.logger.warning("OpenAI returned empty response")
                return []
                
            # Handle both list and dictionary responses
            if isinstance(response, list):
                self.logger.info(f"Extracted location terms: {response}")
                return response
            elif isinstance(response, dict):
                if "error" in response:
                    self.logger.error(f"OpenAI returned error: {response['error']}")
                    return []
                # Try to get the raw content and parse it
                raw_content = response.get("raw_content", "")
                if raw_content:
                    try:
                        # Clean up the content
                        content = raw_content.strip()
                        if content.startswith("[") and content.endswith("]"):
                            import json
                            parsed_terms = json.loads(content)
                            self.logger.info(f"Extracted location terms from raw content: {parsed_terms}")
                            return parsed_terms
                    except json.JSONDecodeError:
                        self.logger.error(f"Failed to parse raw content as JSON: {raw_content}")
                return []
            
            return []
            
        except Exception as e:
            self.logger.error(f"Error extracting location terms: {str(e)}", exc_info=True)
            return []

    async def get_embedding(self, text: str | list) -> list[float]:
        """Get embedding from OpenAI"""
        return await self.openai_client.get_embedding(text)

    async def query_similar_pois(self, embedding: List[float]) -> List[Dict]:
        """Query similar points of interest for the first extracted term."""
        try:
            if not embedding:
                self.logger.warning("No embedding provided for similarity search")
                return []
                
            self.logger.info("Querying similar POIs from database")
            
            # Query similar POIs using the embedding
            results = await self.supabase.rpc(
                'search_similar_pois',
                params={
                    'query_embedding': embedding,
                    'limit_count': 1
                }
            )
            
            # Handle both dictionary and object responses
            final_results = results if isinstance(results, list) else results.get('data', [])
            if final_results:
                self.logger.info(f"Found similar POIs: {[poi.get('name') for poi in final_results]}")
            else:
                self.logger.info("No similar POIs found in database")
            return final_results
        
        except Exception as e:
            self.logger.error(f"Error querying similar POIs: {str(e)}", exc_info=True)
            return []

    async def google_places_search(self, terms: List[str]) -> List[Dict]:
        """Search for places using Google Places API"""
        try:
            if not terms:
                self.logger.info("No terms provided for Google Places search")
                return []
            
            # Take only the first term
            first_term = terms[0]
            self.logger.info(f"Searching Google Places for term: '{first_term}'")
            
            # Search for places using the instance method
            places = await self.google_client.places_search_async(first_term)
            if places:
                self.logger.info(f"Found place in Google Places: {places[0].get('name')} at {places[0].get('address')}")
            else:
                self.logger.info("No places found in Google Places search")
                
            return places
        
        except Exception as e:
            self.logger.error(f"Error searching Google Places: {str(e)}", exc_info=True)
            return []

    async def detect_location(self, query: str, location_id: str = "ChIJe9DRTdUadkgRAlFpoUrfj0c") -> tuple[str, str, str]:
        """Detect and retrieve venue information from query."""
        self.logger.info(f"Starting location detection for query: '{query}'")
        
        # Extract and get embedding
        extracted_terms = await self.extract_terms(query)
        
        if not extracted_terms:
            self.logger.info("No location terms found, using default location")
            response = await self.supabase.query_table(
                'points_of_interest',
                'id,name,location',
                [('id', location_id)]
            )
            # Handle both dictionary and object responses
            data = response if isinstance(response, list) else response.get('data', [])
            poi_data = data[0] if data else {}
            self.logger.info(f"Using default location: {poi_data.get('name', 'Unknown')}")
        else: 
            self.logger.info(f"Processing extracted terms: {extracted_terms}")
            embedding = await self.get_embedding(extracted_terms[0])
            similar_pois = await self.query_similar_pois(embedding)
            
            # Get POI data either from database or Google Places
            if similar_pois:
                # Use existing POI from database if similarity is good enough
                similarity = similar_pois[0].get("similarity", 0)
                self.logger.info(f"Found POI in database with similarity score: {similarity}")
                
                if similarity <= self.SIMILARITY_THRESHOLD:
                    poi_data = similar_pois[0]
                    self.logger.info(f"Using existing POI from database: {poi_data.get('name')} (similarity: {similarity})")
                else:
                    self.logger.info(f"Database match below threshold ({similarity} < {self.SIMILARITY_THRESHOLD}), searching Google Places")
                    google_results = await self.google_places_search(extracted_terms)
                    if not google_results:
                        self.logger.info("No Google Places results found, using closest database match instead")
                        poi_data = similar_pois[0]  # Use the best database match even if below threshold
                    else:
                        google_result = google_results[0]
                        self.logger.info(f"Upserting Google Places result: {google_result.get('name')}")
                        upsert_response = await self.supabase.upsert_data_poi(
                            google_result, 
                            embedding, 
                            "points_of_interest"
                        )
                        # Handle both dictionary and object responses
                        data = upsert_response if isinstance(upsert_response, list) else upsert_response.get('data', [{}])
                        poi_data = data[0]
                        self.logger.info(f"Successfully upserted POI: {poi_data.get('name')}")
            else:
                # No database results at all, try Google Places
                self.logger.info("No matching POIs in database, searching Google Places")
                google_results = await self.google_places_search(extracted_terms)
                if not google_results:
                    self.logger.info("No Google Places results found, using default location")
                    response = await self.supabase.query_table(
                        'points_of_interest',
                        'id,name,location',
                        [('id', location_id)]
                    )
                    # Handle both dictionary and object responses
                    data = response if isinstance(response, list) else response.get('data', [])
                    poi_data = data[0] if data else {}
                else:
                    google_result = google_results[0]
                    self.logger.info(f"Upserting Google Places result: {google_result.get('name')}")
                    upsert_response = await self.supabase.upsert_data_poi(
                        google_result, 
                        embedding, 
                        "points_of_interest"
                    )
                    # Handle both dictionary and object responses
                    data = upsert_response if isinstance(upsert_response, list) else upsert_response.get('data', [{}])
                    poi_data = data[0]

        # Extract required fields
        result = (
            poi_data.get("id", ""),
            poi_data.get("name", ""),
            poi_data.get("location", "")
        )
        self.logger.info(f"Returning location data: {result}")
        return result

    @classmethod
    def get_test_queries(cls) -> List[str]:
        """Get the list of test queries."""
        return cls.TEST_QUERIES

# Example usage with better error handling
if __name__ == "__main__":
    import asyncio
    
    async def main():
        try:
            detector = LocationDetectionAgent()
            logger = logging.getLogger(__name__)
            
            for query in LocationDetectionAgent.TEST_QUERIES:
                try:
                    logger.info(f"\nProcessing test query: '{query}'")
                    location_info = await detector.detect_location(query)
                    logger.info(f"Location info: {location_info}")
                except Exception as e:
                    logger.error(f"Error processing query '{query}': {str(e)}", exc_info=True)
                    continue
                    
        except Exception as e:
            logger.error(f"Failed to initialize LocationDetectionAgent: {str(e)}", exc_info=True)
    
    asyncio.run(main())