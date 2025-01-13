from typing import Dict, Any, List, Tuple
from supabase import create_client, Client
import os
import sys
import logging
import dotenv
import argparse
import asyncio

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.location_detection import LocationDetectionAgent
from agents.preferences_agent import PreferencesAgent
from agents.datetime_detection import DateTimeAgent
from clients.supabase_client import SupabaseClient

# Setup logging
logger = logging.getLogger(__name__)

# Load environment variables
dotenv.load_dotenv()

class RestaurantAgent:
    """Agent for handling restaurant search and recommendations."""
    
    def __init__(self):
        """Initialize the RestaurantAgent with required clients and sub-agents."""
        self.supabase = SupabaseClient()
        self.preferences_agent = PreferencesAgent()
        self.location_detection_agent = LocationDetectionAgent()
        self.date_time_agent = DateTimeAgent()
        
    async def process_query(self, query: str, user_id: str) -> Dict[str, Any]:
        """
        Process a restaurant search query to extract all relevant information.
        
        Args:
            query (str): The search query from the user
            user_id (str): The ID of the user making the request
            
        Returns:
            Dict[str, Any]: Processed query information including:
                - preferences: dietary requirements and cuisine types
                - location: venue ID, name, and address
                - datetime: timing preferences
        """
        try:
            # Extract preferences from query
            preferences = await self.preferences_agent.extract_preferences(query, user_id)
            logging.info(f"Extracted preferences: {preferences}")

            # Get location from query
            location = await self.location_detection_agent.detect_location(query)
            if not location:
                return None
            logging.info(f"Detected location: {location[1]} at {location[2]}")

            # Get datetime info from query
            datetime_info = await self.date_time_agent.process_query(query)
            logging.info(f"Extracted datetime info: {datetime_info}")

            # Return combined results
            return {
                'location': {
                    'id': location[0],
                    'name': location[1],
                    'address': location[2]
                },
                'datetime': datetime_info,
                'required_cuisines': preferences.get('cuisine_types', []),
                'excluded_cuisines': preferences.get('excluded_cuisines', []),
                'dietary_requirements': preferences.get('dietary_requirements', [])
            }
        except Exception as e:
            logging.error(f"Error processing query: {str(e)}")
            return None

# Example usage
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process restaurant queries')
    parser.add_argument('query', type=str, help='The search query (e.g., "Italian Restaurant with @Jim in Covent Garden in April")')
    parser.add_argument('--user-id', type=str, default="a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1",
                      help='User ID (default: a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1)')
    
    args = parser.parse_args()
    
    # Test the agent
    agent = RestaurantAgent()
    
    try:
        results = asyncio.run(agent.process_query(args.query, args.user_id))
        print("\nQuery Results:")
        print(f"Location: {results['location']}")
        print(f"DateTime: {results['datetime']}")
        print(f"Required Cuisines: {results['required_cuisines']}")
        print(f"Dietary Requirements: {results['dietary_requirements']}")
        print(f"Excluded Cuisines: {results['excluded_cuisines']}")
    except Exception as e:
        print(f"Error: {str(e)}")


