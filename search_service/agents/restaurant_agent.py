from typing import Dict, Any, List
from openai import AsyncOpenAI
from supabase import create_client, Client
import os
from .venue_agent import VenueAgent
from .preferences_agent import PreferencesAgent
from .datetime_agent import DateTimeAgent
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
        self.datetime_agent = DateTimeAgent()

    async def find_restaurants(self, query: str, user_id: str) -> Dict[str, Any]:
        """
        Find restaurants near a venue that match user preferences.
        
        Args:
            query (str): User query containing venue, preferences, and datetime info
            user_id (str): ID of the user making the request
            
        Returns:
            Dict containing:
            - venue: Validated venue information from venue_agent
            - preferences: Extracted user/group preferences from preferences_agent
            - datetime: Extracted date and time information
            - restaurants: List of matching restaurants
        """
        try:
            # Get venue, preferences, and datetime in parallel for better performance
            venue_task = self.venue_agent.validate_venue(query)
            preferences_task = self.preferences_agent.extract_preferences(query, user_id)
            datetime_task = self.datetime_agent.extract_datetime(query)
            
            venue, preferences, datetime_info = await asyncio.gather(
                venue_task, 
                preferences_task,
                datetime_task
            )
            
            if 'error' in venue:
                return {'error': venue['error']}

            # Find restaurants near the venue that match preferences
            restaurants = await self._search_restaurants(
                latitude=venue['latitude'],
                longitude=venue['longitude'],
                excluded_cuisines=preferences.get('excluded_cuisines', []),
                cuisine_types=preferences.get('cuisine_types', []),
                dietary_requirements=preferences.get('dietary_requirements', []),
                start_date=datetime_info.get('start_date', ''),
                end_date=datetime_info.get('end_date', ''),
                start_time=datetime_info.get('start_time', ''),
                end_time=datetime_info.get('end_time', ''),
                limit=200
            )

            return {
                'venue': venue,
                'preferences': preferences,
                'datetime': datetime_info,
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
        start_date: str = '',
        end_date: str = '',
        start_time: str = '',
        end_time: str = '',
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """
        Search for restaurants near a location with filters.
        Supports excluded cuisines, specific cuisine types, and datetime filters.
        """
        try:
            # Call the database function to find nearby restaurants
            result = self.supabase.rpc(
                'find_restaurants_near_venue',
                {
                    'venue_lat': latitude,
                    'venue_lon': longitude,
                    'excluded_cuisines': excluded_cuisines if excluded_cuisines else None,
                    'cuisine_types': cuisine_types if cuisine_types else None,
                    'start_date': start_date if start_date else None,
                    'end_date': end_date if end_date else None,
                    'start_time': start_time if start_time else None,
                    'end_time': end_time if end_time else None,
                    'max_results': limit
                }
            ).execute()

            return result.data if result.data else []

        except Exception as e:
            print(f"Error in restaurant search: {e}")
            return [] 