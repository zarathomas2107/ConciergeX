import os
import sys
import json
from typing import Dict, Any, List, Optional
import uuid
import asyncio
from supabase import create_client, Client
from openai import AsyncOpenAI
from dotenv import load_dotenv

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Load environment variables
load_dotenv()

class PreferencesAgent:
    def __init__(self):
        # Initialize Supabase client
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")
        
        if not url or not key:
            raise ValueError("Missing required environment variables: SUPABASE_URL and SUPABASE_KEY/SUPABASE_SERVICE_ROLE_KEY")
        
        self.supabase: Client = create_client(url, key)
        self.openai = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    def query_table(self, table_name: str, schema: str = 'development') -> Any:
        """Helper function to query a table with schema.
        
        Args:
            table_name: Name of the table to query
            schema: Schema name, defaults to 'development'
            
        Returns:
            The table query builder
        """
        return self.supabase.table(f'{schema}.{table_name}')

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
            # Run the synchronous operation in a thread pool
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self.supabase.table('profiles')
                    .select('dietary_requirements, excluded_cuisines')
                    .eq('id', user_id)
                    .execute()
            )
            
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

    async def get_group_preferences(self, group_name: str, user_id: str) -> Dict[str, Any]:
        try:
            # Get group details using run_in_executor
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self.supabase.rpc(
                    'get_group_members_preferences',
                    {'group_name': group_name, 'user_id': user_id}
                ).execute()
            )
            
            if not response.data:
                print(f"No preferences found for group {group_name}")
                return {
                    'dietary_requirements': [],
                    'excluded_cuisines': []
                }
            
            # Extract preferences from the response
            preferences = response.data[0]
            dietary_requirements = preferences.get('dietary_requirements', [])
            excluded_cuisines = preferences.get('excluded_cuisines', [])
            
            print(f"Found preferences for group {group_name}:")
            print(f"Dietary requirements: {dietary_requirements}")
            print(f"Excluded cuisines: {excluded_cuisines}")
            
            return {
                'dietary_requirements': dietary_requirements,
                'excluded_cuisines': excluded_cuisines
            }
            
        except Exception as e:
            print(f"Error getting group preferences: {str(e)}")
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
            # Run the synchronous operation in a thread pool
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self.supabase.rpc('get_user_groups', {'user_id_input': user_id}).execute()
            )
            
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
                preferences = await self.get_group_preferences(extracted['group'], user_id)
                print(f"Group preferences: {preferences}")
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