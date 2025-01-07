import os
from typing import List, Dict, Any, Tuple, Optional
from supabase import create_client, Client
import logging
from dotenv import load_dotenv
import httpx
import re

# Load environment variables (only for local development)
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SupabaseClient:
    """Client for interacting with Supabase database."""
    
    def __init__(self):
        """Initialize the Supabase client with credentials from environment variables."""
        try:
            # Get environment variables
            self.url = os.getenv("SUPABASE_URL")
            self.key = os.getenv("SUPABASE_ANON_KEY")
            
            # Log environment variable status (without exposing sensitive data)
            logger.info("Checking Supabase environment variables...")
            logger.info(f"SUPABASE_URL is {'set' if self.url else 'not set'}")
            logger.info(f"SUPABASE_ANON_KEY is {'set' if self.key else 'not set'}")
            
            if not self.url or not self.key:
                raise ValueError(
                    "Missing Supabase credentials. "
                    "SUPABASE_URL and SUPABASE_ANON_KEY must be set in environment variables."
                )
            
            # Log URL format (first 8 chars only for security)
            logger.info(f"Supabase URL format check - starts with: {self.url[:8]}...")
            
            # Log API key format (first 8 chars only for security)
            logger.info(f"Supabase API key format check - starts with: {self.key[:8]}...")
            
            # Validate URL format
            if not self._is_valid_url(self.url):
                raise ValueError(
                    f"Invalid Supabase URL format. "
                    f"URL should start with https:// and be a valid Supabase project URL. "
                    f"Current URL starts with: {self.url[:8]}..."
                )
            
            # Validate API key format
            if not self._is_valid_api_key(self.key):
                raise ValueError(
                    f"Invalid Supabase API key format. "
                    f"API key should be a JWT token. "
                    f"Current key starts with: {self.key[:8]}..."
                )
                
            # Initialize client
            logger.info("Creating Supabase client...")
            self.client = create_client(self.url, self.key)
            logger.info("Successfully initialized Supabase client")
            
        except Exception as e:
            logger.error(f"Error initializing Supabase client: {str(e)}")
            raise
    
    def _is_valid_url(self, url: str) -> bool:
        """Validate URL format."""
        if not url:
            return False
        # Basic URL validation
        url_pattern = re.compile(
            r'^https?://'  # http:// or https://
            r'([A-Za-z0-9\-\.]+)'  # domain
            r'(:[0-9]+)?'  # optional port
            r'(/.*)?$'  # path
        )
        return bool(url_pattern.match(url))
    
    def _is_valid_api_key(self, key: str) -> bool:
        """Validate API key format."""
        if not key:
            return False
        # Basic JWT format validation (three parts separated by dots)
        key_pattern = re.compile(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$')
        return bool(key_pattern.match(key))
            
    async def query_table(
        self,
        table_name: str,
        columns: str,
        conditions: List[Tuple] = None
    ) -> List[Dict[str, Any]]:
        """
        Query a table with specified columns and conditions.
        
        Args:
            table_name (str): Name of the table to query
            columns (str): Comma-separated list of columns to select
            conditions (List[Tuple], optional): List of (column, value) or (column, operator, value) tuples
            
        Returns:
            List[Dict[str, Any]]: Query results as a list of dictionaries
        """
        try:
            logger.info(f"Querying table '{table_name}' for columns: {columns} with conditions: {conditions}")
            
            # Execute the query
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.url}/rest/v1/{table_name}",
                    params={"select": columns, **self._build_conditions(conditions)} if conditions else {"select": columns},
                    headers={
                        "apikey": self.key,
                        "Authorization": f"Bearer {self.key}"
                    }
                )
                response.raise_for_status()
                return response.json()
                
        except Exception as e:
            logger.error(f"Database error querying table {table_name}: {str(e)}")
            return []
            
    def _build_conditions(self, conditions: List[Tuple]) -> Dict[str, str]:
        """Build query parameters for conditions."""
        params = {}
        for condition in conditions:
            if len(condition) == 2:
                column, value = condition
                params[f"{column}"] = f"eq.{value}"
            elif len(condition) == 3:
                column, operator, value = condition
                params[f"{column}"] = f"{operator}.{value}"
        return params
            
    async def rpc(self, function_name: str, params: Dict = None) -> List[Dict[str, Any]]:
        """
        Call a Postgres function via RPC.
        
        Args:
            function_name (str): Name of the function to call
            params (Dict, optional): Parameters to pass to the function
            
        Returns:
            List[Dict[str, Any]]: Function results as a list of dictionaries
        """
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.url}/rest/v1/rpc/{function_name}",
                    json=params,
                    headers={
                        "apikey": self.key,
                        "Authorization": f"Bearer {self.key}",
                        "Content-Type": "application/json"
                    }
                )
                response.raise_for_status()
                return response.json()
                
        except Exception as e:
            logger.error(f"Error calling RPC function {function_name}: {str(e)}")
            return []
            
    async def upsert_data_poi(
        self,
        data: Dict[str, Any],
        embedding: List[float],
        table_name: str
    ) -> List[Dict[str, Any]]:
        """
        Upsert data into a table.
        
        Args:
            data (Dict[str, Any]): Data to upsert
            embedding (List[float]): Embedding vector
            table_name (str): Name of the table
            
        Returns:
            List[Dict[str, Any]]: Upsert results as a list of dictionaries
        """
        try:
            logger.info(f"Starting upsert operation for {table_name} with ID: {data.get('id')}")
            
            # Prepare the data with embedding
            upsert_data = {
                **data,
                "embedding": embedding
            }
            logger.debug(f"Prepared upsert data for {table_name} (excluding embedding vector)")
            
            async with httpx.AsyncClient() as client:
                # First try to get existing record
                logger.debug(f"Checking for existing record with ID: {data.get('id')}")
                response = await client.get(
                    f"{self.url}/rest/v1/{table_name}",
                    params={"id": f"eq.{data.get('id')}"},
                    headers={
                        "apikey": self.key,
                        "Authorization": f"Bearer {self.key}"
                    }
                )
                response.raise_for_status()
                existing_records = response.json()
                
                if existing_records:
                    logger.info(f"Found existing record for ID {data.get('id')}, updating...")
                    response = await client.patch(
                        f"{self.url}/rest/v1/{table_name}",
                        params={"id": f"eq.{data.get('id')}"},
                        json=upsert_data,
                        headers={
                            "apikey": self.key,
                            "Authorization": f"Bearer {self.key}",
                            "Content-Type": "application/json",
                            "Prefer": "return=representation"
                        }
                    )
                else:
                    logger.info(f"No existing record found for ID {data.get('id')}, inserting new record...")
                    response = await client.post(
                        f"{self.url}/rest/v1/{table_name}",
                        json=upsert_data,
                        headers={
                            "apikey": self.key,
                            "Authorization": f"Bearer {self.key}",
                            "Content-Type": "application/json",
                            "Prefer": "return=representation"
                        }
                    )
                    
                response.raise_for_status()
                result = response.json()
                logger.info(f"Successfully upserted data in {table_name} with ID: {data.get('id')}")
                return result
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error during upsert operation: {str(e)}")
            logger.error(f"Failed request URL: {e.request.url}")
            logger.error(f"Response status code: {e.response.status_code if hasattr(e, 'response') else 'N/A'}")
            return []
        except Exception as e:
            logger.error(f"Unexpected error during upsert operation: {str(e)}")
            return []

    async def update_table(
        self,
        table_name: str,
        data: Dict[str, Any],
        conditions: List[Tuple]
    ) -> List[Dict[str, Any]]:
        """
        Update records in a table that match the conditions.
        
        Args:
            table_name (str): Name of the table to update
            data (Dict[str, Any]): Data to update
            conditions (List[Tuple]): List of (column, value) or (column, operator, value) tuples
            
        Returns:
            List[Dict[str, Any]]: Updated records
        """
        try:
            logger.info(f"Updating table '{table_name}' with data: {data} and conditions: {conditions}")
            
            async with httpx.AsyncClient() as client:
                response = await client.patch(
                    f"{self.url}/rest/v1/{table_name}",
                    params=self._build_conditions(conditions),
                    json=data,
                    headers={
                        "apikey": self.key,
                        "Authorization": f"Bearer {self.key}",
                        "Content-Type": "application/json",
                        "Prefer": "return=representation"
                    }
                )
                response.raise_for_status()
                result = response.json()
                logger.info(f"Successfully updated {len(result)} records in {table_name}")
                return result
                
        except Exception as e:
            logger.error(f"Error updating table {table_name}: {str(e)}")
            return []
