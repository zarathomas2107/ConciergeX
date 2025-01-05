import os
import logging
from supabase import Client
from supabase.client import create_client
from typing import Dict, Any, List, Tuple, Optional

logger = logging.getLogger(__name__)

class SupabaseClient:
    def __init__(self):
        self.url = os.environ.get("SUPABASE_URL")
        self.key = os.environ.get("SUPABASE_ANON_KEY")
        if not self.url or not self.key:
            raise ValueError("SUPABASE_URL and SUPABASE_ANON_KEY must be set in environment variables")
        
        # Initialize the Supabase client
        self.client: Client = create_client(self.url, self.key)


    def poi_prep(self, data: Dict, embedding: List[float] = None) -> Dict:
        """Convert None values in a dictionary to appropriate defaults based on field type.
        
        Args:
            data (Dict): Dictionary to process
            embedding (List[float], optional): Embedding to set in the dictionary
            
        Returns:
            Dict: Dictionary with None values converted to appropriate defaults
        """
        result = {}
        for k, v in data.items():
            if v is None:
                if k == 'rating':
                    result[k] = 0.0  # Default for rating
                elif k in ['latitude', 'longitude']:
                    result[k] = 0.0  # Default for geo coordinates
                elif k == 'user_ratings_total':
                    result[k] = 0    # Default for integer fields
                else:
                    result[k] = "null"
            else:
                result[k] = v
                
        if embedding:
            result['embedding'] = embedding
        return result
    

    def query_table(self, table_name: str, columns: str = "*", conditions: Optional[List[Tuple[str, Any]]] = None):
        """
        Query a table using Supabase client with optional columns and conditions
        
        Args:
            table_name (str): Name of the table to query
            columns (str): Comma-separated list of columns to select (default "*" for all columns)
            conditions (List[Tuple[str, Any]], optional): List of (field, value) tuples for equality conditions
            
        Example:
            # Query specific columns
            query_table('restaurants_features', 'id,name,rating')
            
            # Query specific columns with conditions
            query_table(
                'restaurants_features',
                'id,dog_friendly,dinner',
                [('id', 'some-id'), ('dog_friendly', True)]
            )
        """
        try:
            # Start the query with specified columns
            query = self.client.table(table_name).select(columns)
            
            # Add equality conditions if provided
            if conditions:
                for field, value in conditions:
                    if value is None:
                        query = query.is_(field, 'null')
                    else:
                        query = query.eq(field, value)
            
            # Execute the query
            response = query.execute()
            return response
        except Exception as e:
            logger.error(f"Error querying table {table_name}: {str(e)}")
            raise

    def update_table(self, table_name: str, data: Dict[str, Any], conditions: List[Tuple[str, Any]]):
        """
        Updates a table using Supabase client with multiple conditions
        
        Args:
            table_name (str): Name of the table to update
            data (Dict[str, Any]): Dictionary of field names and values to update
            conditions (List[Tuple[str, Any]]): List of (field, value) tuples for conditions
            
        Example:
            update_table(
                'restaurants_features',
                {"dog_friendly": False, "dinner": True},
                [("dog_friendly", True), ("id", "ChIJ123456789")]
            )
        """
        try:
            # Start the update query
            query = self.client.table(table_name).update(data)
            
            # Add all conditions
            for field, value in conditions:
                if value is None:
                    query = query.is_(field, 'null')
                else:
                    query = query.eq(field, value)
            
            # Execute the query
            response = query.execute()
            return response
        except Exception as e:
            logger.error(f"Error updating table {table_name}: {str(e)}")
            raise


    def upsert_data_poi(self, data: Dict[str, Any], embedding: List[float], table_name: str = "points_of_interest"):
        """
        Upsert data into points of interest table

        Args:
            data (Dict[str, Any]): Dictionary of field names and values to upsert
            embedding (List[float]): Embedding vector for the POI
            table_name (str, optional): Name of the table to upsert data into. Defaults to "points_of_interest"
        """

        logger.info(f"Upserting data into table {table_name}:")
        try:
            formatted_data = self.poi_prep(data, embedding)
            response = self.client.table(table_name).upsert(formatted_data, on_conflict="id").execute()
                    # Check if data is returned in the response
            if response and response.data:
                logger.info(f"✅ Upsert successful! Rows affected: {len(response.data)}")
                return {
                    "status": "success",
                    "message": f"{len(response.data)} rows inserted/updated.",
                    "data": response.data
                }
            else:
                logger.warning("⚠️ Upsert completed but no rows were returned.")
                return {
                    "status": "warning",
                    "message": "Upsert completed, but no rows were returned."
                }
        except Exception as e:
            logger.error(f"Error upserting data into table {table_name}: {str(e)}")
            raise

    def rpc(self, function_name: str, params: Dict[str, Any]):
        """
        Execute a stored procedure using Supabase client
        """
        return self.client.rpc(function_name, params).execute()
