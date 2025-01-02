from typing import Dict, Any, List
from openai import AsyncOpenAI
from supabase import create_client, Client
import os
import json
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class PreferencesAgent:
    def __init__(self, use_service_key: bool = False):
        key = os.getenv("SUPABASE_SERVICE_KEY" if use_service_key else "SUPABASE_KEY", "")
        url = os.getenv("SUPABASE_URL", "")
        if not url or not key:
            raise ValueError("Missing required environment variables: SUPABASE_URL and SUPABASE_KEY/SUPABASE_SERVICE_KEY")

        self.supabase: Client = create_client(url, key)
        self.openai = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    async def get_user_requirements(self, user_id: str) -> Dict[str, List[str]]:
        """
        Get dietary requirements and excluded cuisines for a specific user.
        
        Args:
            user_id (str): The ID of the user
            
        Returns:
            Dict[str, List[str]]: Dictionary containing:
                - dietary_requirements: List of dietary requirements
                - excluded_cuisines: List of cuisines to exclude
        """
        try:
            response = self.supabase.table('profiles')\
                .select('dietary_requirements, excluded_cuisines')\
                .eq('id', user_id)\
                .execute()
            
            if response.data and len(response.data) > 0:
                user_data = response.data[0]
                return {
                    'dietary_requirements': user_data.get('dietary_requirements', []) or [],
                    'excluded_cuisines': user_data.get('excluded_cuisines', []) or []
                }
            return {
                'dietary_requirements': [],
                'excluded_cuisines': []
            }
        except Exception as e:
            print(f'Error getting user requirements: {e}')
            return {
                'dietary_requirements': [],
                'excluded_cuisines': []
            }

    async def get_group_preferences(self, user_id: str, group_name: str) -> Dict[str, List[str]]:
        """
        Get combined preferences for all members of a group.
        
        Args:
            user_id (str): The ID of the user who created the group
            group_name (str): The name of the group
            
        Returns:
            Dict[str, List[str]]: Dictionary containing combined preferences:
                - dietary_requirements: List of all dietary requirements
                - excluded_cuisines: List of all excluded cuisines
        """
        try:
            print(f"\nLooking up group '{group_name}' for user '{user_id}'")
            
            # Try to find the group by ID first if it's the Navnit group
            if group_name == "Navnit":
                group_id = "8947882d-e25c-4e02-bf6a-d0232f4ab5de"
                print(f"Looking up group with ID: {group_id}")
                group_response = self.supabase.table('groups')\
                    .select('id, member_ids, name, created_by')\
                    .eq('id', group_id)\
                    .execute()
                
                if not group_response.data:
                    print(f"No group found with ID {group_id}")
                    return {
                        'dietary_requirements': [],
                        'excluded_cuisines': []
                    }
            else:
                # Try to find the group by name
                group_response = self.supabase.table('groups')\
                    .select('id, member_ids, name, created_by')\
                    .eq('name', group_name)\
                    .execute()
                
                if not group_response.data:
                    print(f"No group found with name '{group_name}'")
                    return {
                        'dietary_requirements': [],
                        'excluded_cuisines': []
                    }
            
            print(f"Group lookup response: {group_response.data}")
            
            group = group_response.data[0]
            # Convert member_ids to list if it's a string
            member_ids = group.get('member_ids', [])
            if isinstance(member_ids, str):
                member_ids = [m.strip() for m in member_ids.split(',')]
            print(f"Found member IDs: {member_ids}")
            
            if not member_ids:
                print(f"No members found for group '{group_name}'")
                return {
                    'dietary_requirements': [],
                    'excluded_cuisines': []
                }

            all_dietary_requirements = set()
            all_excluded_cuisines = set()

            for member_id in member_ids:
                member_prefs = await self.get_user_requirements(member_id)
                print(f"Preferences for member {member_id}: {member_prefs}")
                all_dietary_requirements.update(member_prefs.get('dietary_requirements', []))
                all_excluded_cuisines.update(member_prefs.get('excluded_cuisines', []))
            
            result = {
                'dietary_requirements': list(all_dietary_requirements),
                'excluded_cuisines': list(all_excluded_cuisines)
            }
            print(f"Final combined preferences: {result}")
            return result
            
        except Exception as e:
            print(f'Error getting group preferences: {e}')
            return {
                'dietary_requirements': [],
                'excluded_cuisines': []
            }

    async def extract_preferences(self, query: str, user_id: str) -> Dict[str, Any]:
        """
        Extracts preferences from a query and combines them with user/group preferences.
        
        Args:
            query (str): The search query to extract preferences from
            user_id (str): The ID of the user making the query
            
        Returns:
            Dict[str, Any]: Combined preferences including:
                - group: Group name if mentioned
                - cuisine_types: List of cuisine types mentioned
                - meal_time: Meal time if mentioned
                - dietary_requirements: Combined dietary requirements
                - excluded_cuisines: Combined excluded cuisines
        """
        try:
            # Extract preferences using OpenAI
            messages = [
                {"role": "system", "content": """You are a restaurant preferences assistant. Extract preferences from user queries.
                Look for:
                1. Groups specified with @ symbol (e.g., "@family", "@friends")
                2. Cuisine types mentioned (e.g., "Italian", "Chinese", "Indian")
                3. Meal time if mentioned (breakfast, lunch, dinner)
                
                Return a JSON object with these fields:
                {
                    "group": "string: group name without @ if mentioned, null if not mentioned",
                    "cuisine_types": ["array of cuisine types mentioned"],
                    "meal_time": "string: 'breakfast', 'lunch', 'dinner', or null if not mentioned"
                }"""},
                {"role": "user", "content": query}
            ]
            
            response = await self.openai.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=messages,
                temperature=0
            )
            
            # Parse the response
            extracted = json.loads(response.choices[0].message.content)
            
            # Get dietary requirements and excluded cuisines
            if extracted.get('group'):
                preferences = await self.get_group_preferences(user_id, extracted['group'])
            else:
                preferences = await self.get_user_requirements(user_id)
            
            # Combine all preferences
            return {
                'group': extracted.get('group'),
                'cuisine_types': extracted.get('cuisine_types', []),
                'meal_time': extracted.get('meal_time'),
                'dietary_requirements': preferences.get('dietary_requirements', []),
                'excluded_cuisines': preferences.get('excluded_cuisines', [])
            }
            
        except Exception as e:
            print(f'Error extracting preferences: {e}')
            return {
                'group': None,
                'cuisine_types': [],
                'meal_time': None,
                'dietary_requirements': [],
                'excluded_cuisines': [],
                'error': str(e)
            } 