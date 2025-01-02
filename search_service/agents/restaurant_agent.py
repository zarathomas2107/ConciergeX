from typing import Dict, Any, List
from openai import AsyncOpenAI
from supabase import create_client, Client
import os
from .venue_agent import VenueAgent
from .preferences_agent import PreferencesAgent
import asyncio

class RestaurantAgent:
    def __init__(self, use_service_key: bool = False):
        key = os.getenv("SUPABASE_SERVICE_KEY" if use_service_key else "SUPABASE_KEY", "")
        url = os.getenv("SUPABASE_URL", "")
        if not url or not key:
            raise ValueError("Missing required environment variables")

        self.supabase: Client = create_client(url, key)
        self.venue_agent = VenueAgent()
        self.preferences_agent = PreferencesAgent(use_service_key)

    async def find_restaurants(self, query: str, user_id: str) -> Dict[str, Any]:
        """
        Find restaurants near a venue that match user preferences.
        
        Args:
            query (str): User query containing venue and preferences
            user_id (str): ID of the user making the request
            
        Returns:
            Dict containing:
            - venue: Validated venue information from venue_agent
            - preferences: Extracted user/group preferences from preferences_agent
            - restaurants: List of matching restaurants
        """
        try:
            # Get venue and preferences in parallel for better performance
            venue_task = self.venue_agent.validate_venue(query)
            preferences_task = self.preferences_agent.extract_preferences(query, user_id)
            
            venue, preferences = await asyncio.gather(venue_task, preferences_task)
            
            if 'error' in venue:
                return {'error': venue['error']}

            # Find restaurants near the venue that match preferences
            restaurants = await self._search_restaurants(
                latitude=venue['latitude'],
                longitude=venue['longitude'],
                excluded_cuisines=preferences.get('excluded_cuisines', []),
                cuisine_types=preferences.get('cuisine_types', []),
                dietary_requirements=preferences.get('dietary_requirements', []),
                limit=200
            )

            return {
                'venue': venue,
                'preferences': preferences,
                'restaurants': restaurants
            }

        except Exception as e:
            print(f"Error finding restaurants: {e}")
            return {'error': str(e)}

    async def _search_restaurants(
        self,
        latitude: float,
        longitude: float,
        excluded_cuisines: List[str],
        cuisine_types: List[str],
        dietary_requirements: List[str],
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """
        Search for restaurants near a location with filters.
        Currently only supports excluded cuisines filter.
        """
        try:
            # Call the database function to find nearby restaurants
            result = self.supabase.rpc(
                'find_restaurants_near_venue',
                {
                    'venue_lat': latitude,
                    'venue_lon': longitude,
                    'excluded_cuisines': excluded_cuisines if excluded_cuisines else None,
                    'max_results': limit
                }
            ).execute()

            return result.data if result.data else []

        except Exception as e:
            print(f"Error in restaurant search: {e}")
            return [] 