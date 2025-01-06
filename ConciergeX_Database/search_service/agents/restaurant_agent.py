from typing import Dict, Any, List, Tuple
from supabase import create_client, Client
import os
from search_service.agents.location_detection import LocationDetectionAgent
from search_service.agents.preferences import PreferencesAgent
from search_service.agents.datetime_detection import DateTimeAgent
from search_service.clients.supabase_client import SupabaseClient
import logging
import dotenv
import sys
import argparse

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
        
    def process_query(self, query: str, user_id: str) -> Dict[str, Any]:
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
            # Extract user/group preferences
            preferences = self.preferences_agent.extract_preferences(
                query=query, 
                user_id=user_id
            )
            logger.info(f"Extracted preferences: {preferences}")
            
            # Detect location
            location_id, venue_name, address = self.location_detection_agent.detect_location(
                query=query
            )
            logger.info(f"Detected location: {venue_name} at {address}")
            
            # Extract date/time preferences
            datetime_info = self.date_time_agent.process_query(query)
            logger.info(f"Extracted datetime info: {datetime_info}")
            
            return {
                "preferences": preferences,
                "location": {
                    "id": location_id,
                    "name": venue_name,
                    "address": address
                },
                "datetime": datetime_info
            }
            
        except Exception as e:
            logger.error(f"Error processing query: {str(e)}")
            raise

# Example usage
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process restaurant queries')
    parser.add_argument('query', type=str, help='The search query (e.g., "Italian Restaurant with @Family in April")')
    parser.add_argument('--user-id', type=str, default="a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1",
                      help='User ID (default: a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1)')
    
    args = parser.parse_args()
    
    # Test the agent
    agent = RestaurantAgent()
    
    try:
        results = agent.process_query(args.query, args.user_id)
        print("\nQuery Results:")
        print(f"Preferences: {results['preferences']}")
        print(f"Location: {results['location']}")
        print(f"DateTime: {results['datetime']}")
    except Exception as e:
        print(f"Error: {str(e)}")


