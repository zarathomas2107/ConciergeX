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
                # Normalize case and deduplicate excluded cuisines
                raw_cuisines = user_data.get('excluded_cuisines', []) or []
                excluded_cuisines = list({cuisine.title() for cuisine in raw_cuisines})
                return {
                    'dietary_requirements': user_data.get('dietary_requirements', []) or [],
                    'excluded_cuisines': excluded_cuisines
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
            member_ids = group.get('member_ids', [])
            print(f"Found member IDs: {member_ids}")
            
            # Initialize sets for unique values
            dietary_requirements = set()
            excluded_cuisines_raw = []
            
            # Get preferences for each member
            for member_id in member_ids:
                member_prefs = await self.get_user_requirements(member_id)
                print(f"Preferences for member {member_id}: {member_prefs}")
                
                # Add to sets (will automatically deduplicate)
                dietary_requirements.update(member_prefs.get('dietary_requirements', []))
                excluded_cuisines_raw.extend(member_prefs.get('excluded_cuisines', []))
            
            # Normalize and deduplicate excluded cuisines
            excluded_cuisines = list({cuisine.title() for cuisine in excluded_cuisines_raw})
            
            # Convert back to lists
            final_prefs = {
                'dietary_requirements': list(dietary_requirements),
                'excluded_cuisines': excluded_cuisines
            }
            print(f"Final combined preferences: {final_prefs}")
            return final_prefs
            
        except Exception as e:
            print(f'Error getting group preferences: {e}')
            return {
                'dietary_requirements': [],
                'excluded_cuisines': []
            }

    async def get_available_groups(self, user_id: str) -> List[Dict[str, Any]]:
        """
        Get all groups that the user is a member of or has created.
        
        Args:
            user_id (str): The ID of the user
            
        Returns:
            List[Dict[str, Any]]: List of groups with their details
        """
        try:
            response = self.supabase.rpc('get_user_groups', {'user_id_input': user_id}).execute()
            
            if response.data:
                return response.data
            return []
            
        except Exception as e:
            print(f'Error getting available groups: {e}')
            return []

    async def extract_preferences(self, query: str, user_id: str) -> Dict[str, Any]:
        """
        Extracts preferences from a query and combines them with user/group preferences.
        
        Args:
            query (str): The search query to extract preferences from
            user_id (str): The ID of the user making the query
            
        Returns:
            Dict[str, Any]: Combined preferences including:
                - group: Group name if mentioned
                - available_groups: List of available groups if @ is mentioned without a specific group
                - cuisine_types: List of cuisine types mentioned
                - meal_time: Meal time if mentioned
                - dietary_requirements: Combined dietary requirements
                - excluded_cuisines: Combined excluded cuisines
        """
        try:
            # Check if query contains @ without a specific group
            if '@' in query and not any(c.isalnum() for c in query[query.index('@')+1:].split()[0]):
                # Get available groups
                available_groups = await self.get_available_groups(user_id)
                return {
                    'group': None,
                    'available_groups': available_groups,
                    'cuisine_types': [],
                    'meal_time': None,
                    'dietary_requirements': [],
                    'excluded_cuisines': []
                }

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
                'available_groups': None,  # Only included when @ is used without a group name
                'cuisine_types': extracted.get('cuisine_types', []),
                'meal_time': extracted.get('meal_time'),
                'dietary_requirements': preferences.get('dietary_requirements', []),
                'excluded_cuisines': preferences.get('excluded_cuisines', [])
            }
            
        except Exception as e:
            print(f'Error extracting preferences: {e}')
            return {
                'group': None,
                'available_groups': None,
                'cuisine_types': [],
                'meal_time': None,
                'dietary_requirements': [],
                'excluded_cuisines': [],
                'error': str(e)
            } 