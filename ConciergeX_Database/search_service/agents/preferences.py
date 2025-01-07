from typing import Dict, Any, List, Tuple
from search_service.clients.openai_client import OpenAIClient
from search_service.clients.supabase_client import SupabaseClient
from dotenv import load_dotenv
import logging
import traceback
import uuid

# Load environment variables
load_dotenv()

logger = logging.getLogger(__name__)

class PreferencesAgent:
    """Agent for handling user and group preferences for restaurant searches."""
    
    def __init__(self):
        """Initialize the PreferencesAgent with required clients."""
        self.supabase = SupabaseClient()
        self.openai_client = OpenAIClient()
        
        # System prompt for LLM
        self.system_prompt = """
            You are a restaurant preferences assistant. Extract preferences from user queries.
            Look for:
            1. Groups specified with @ symbol (e.g., "@family", "@friends") - REMOVE the @ symbol in your response
            2. Cuisine types mentioned (e.g., "Italian", "Chinese", "Indian")
            
            Example input: "Looking for @family Italian dinner"
            Example output: {"group": "family", "cuisine_types": ["Italian"]}
            
            Return a JSON object with these fields:
            {
                "group": "string: group name with @ symbol REMOVED if mentioned, null if not mentioned",
                "cuisine_types": ["array of cuisine types mentioned"],
            }   
        """.strip()

    async def extract_terms(self, query: str) -> Dict[str, Any]:
        """
        Extracts terms denoting user preferences from a query.
        
        Args:
            query (str): The search query to extract terms from
                
        Returns:
            Dict[str, Any]: Extracted preferences including:
                - group: Group name if mentioned
                - cuisine_types: List of cuisine types mentioned
        """
        logger.info(f"Extracting preferences from query: {query}")        
        
        response = await self.openai_client.get_completion(
            query,
            system_prompt=self.system_prompt
        )
        
        if not response:
            logger.error("No response from OpenAI")
            return {"group": None, "cuisine_types": []}
            
        return {
            "group": response.get("group"),
            "cuisine_types": response.get("cuisine_types", [])
        }

    async def get_user_preferences(self, user_id: str) -> Tuple[List[str], List[str]]:
        """
        Get dietary requirements and excluded cuisines for a user from their profile.
        
        Args:
            user_id (str): The ID of the user to fetch preferences for
            
        Returns:
            Tuple[List[str], List[str]]: A tuple containing:
                - List of dietary requirements
                - List of excluded cuisines
                
        Raises:
            Exception: If there's an error querying the database or user not found
        """
        try:
            # Validate UUID format
            uuid.UUID(user_id)
            
            response = await self.supabase.query_table(
                table_name='profiles',
                columns='dietary_requirements, excluded_cuisines',
                conditions=[("id", user_id)]
            )
            
            # Handle both dictionary and object responses
            data = response if isinstance(response, list) else response.get('data', [])
            
            if not data:
                logger.error(f"No profile found for user: {user_id}")
                return [], []
                
            user_data = data[0]
            dietary_requirements = user_data.get('dietary_requirements') or []
            excluded_cuisines = user_data.get('excluded_cuisines') or []
            
            logger.info(f"Retrieved preferences for user {user_id}: {len(dietary_requirements)} dietary requirements, {len(excluded_cuisines)} excluded cuisines")
            return dietary_requirements, excluded_cuisines
            
        except ValueError:
            logger.error(f"Invalid UUID format for user_id: {user_id}")
            return [], []
        except Exception as e:
            logger.error(f"Error getting user preferences: {str(e)}")
            return [], []

    async def get_group_preferences(self, user_id: str, group_name: str) -> Dict[str, List[str]]:
        """
        Get combined dietary preferences for all members of a group.
        
        Args:
            user_id (str): ID of the user who created the group
            group_name (str): Name of the group to fetch preferences for
            
        Returns:
            Dict[str, List[str]]: Combined group preferences with:
                - dietary_requirements: List of unique dietary requirements
                - excluded_cuisines: List of unique excluded cuisines
        """
        try:
            # Validate UUID format
            uuid.UUID(user_id)
            
            # Query group members
            logger.info(f"Querying groups table for group: {group_name} (created by user: {user_id})")
            response = await self.supabase.query_table(
                table_name='groups',
                columns='member_ids',
                conditions=[
                    ("created_by", user_id),
                    ("name", group_name.lower())
                ]
            )
            
            # Handle both dictionary and object responses
            data = response if isinstance(response, list) else response.get('data', [])
            
            if not data:
                logger.error(f"No group found with name: {group_name}")
                return {'dietary_requirements': [], 'excluded_cuisines': []}
                
            member_ids = data[0].get('member_ids', [])
            if not member_ids:
                logger.warning(f"Group {group_name} has no members")
                return {'dietary_requirements': [], 'excluded_cuisines': []}
            
            dietary_requirements_set = set()
            excluded_cuisines_set = set()
            
            for member_id in member_ids:
                try:
                    dietary_requirements, excluded_cuisines = await self.get_user_preferences(member_id)
                    dietary_requirements_set.update(dietary_requirements or [])
                    excluded_cuisines_set.update(excluded_cuisines or [])
                except Exception as e:
                    logger.error(f"Error getting preferences for member {member_id}: {str(e)}")
                    continue

            return {
                'dietary_requirements': list(dietary_requirements_set),
                'excluded_cuisines': list(excluded_cuisines_set)
            }
            
        except ValueError:
            logger.error(f"Invalid UUID format for user_id: {user_id}")
            return {'dietary_requirements': [], 'excluded_cuisines': []}
        except Exception as e:
            logger.error(f"Error getting group preferences: {str(e)}")
            return {'dietary_requirements': [], 'excluded_cuisines': []}

    async def extract_preferences(self, query: str, user_id: str) -> Dict[str, Any]:
        """
        Extract and combine user/group preferences with query terms.
        
        Args:
            query (str): The search query to extract terms from
            user_id (str): The ID of the user making the request
            
        Returns:
            Dict[str, Any]: Combined preferences including:
                - dietary_requirements: List of dietary requirements
                - excluded_cuisines: List of excluded cuisines
                - group: Group name if specified
                - cuisine_types: List of cuisine types from query
        """
        try:
            # Extract terms from the query
            extracted_terms = await self.extract_terms(query)
            group_name = extracted_terms.get('group')
            
            # Get user or group preferences
            if group_name:
                preferences = await self.get_group_preferences(user_id, group_name)
            else:
                dietary_requirements, excluded_cuisines = await self.get_user_preferences(user_id)
                preferences = {
                    'dietary_requirements': dietary_requirements,
                    'excluded_cuisines': excluded_cuisines
                }
                
            # Combine preferences with extracted terms
            return {
                'dietary_requirements': preferences.get('dietary_requirements', []),
                'excluded_cuisines': preferences.get('excluded_cuisines', []),
                'group': extracted_terms.get('group'),
                'cuisine_types': extracted_terms.get('cuisine_types', [])
            }
        except Exception as e:
            tb = traceback.extract_tb(e.__traceback__)
            filename, lineno, funcname, text = tb[-1]
            error_message = f"Traceback: File '{filename}', line {lineno}, in {funcname}: {str(e)}"
            logger.error(error_message)
            return {
                'dietary_requirements': [],
                'excluded_cuisines': [],
                'group': None,
                'cuisine_types': []
            }