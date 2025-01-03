import os
import logging
from supabase import create_client, Client
from ..utils.logging_utils import clean_params_for_logging

logger = logging.getLogger(__name__)

class SupabaseClient:
    def __init__(self):
        url = os.environ.get("SUPABASE_URL")
        key = os.environ.get("SUPABASE_KEY")
        self.client: Client = create_client(url, key)

    def rpc(self, function_name: str, params: dict = None):
        """Make an RPC call to Supabase"""
        logger.info(f"Making RPC call to {function_name} with params: {clean_params_for_logging(params)}")
        response = self.client.rpc(function_name, params).execute()
        logger.info(f"RPC response: {response.data}")
        return response 