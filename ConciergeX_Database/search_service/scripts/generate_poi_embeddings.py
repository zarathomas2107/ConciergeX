import os
import requests
from dotenv import load_dotenv
from search_service.clients.supabase_client import SupabaseClient
import logging
import time
from tqdm import tqdm
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables from .env
load_dotenv()

# Initialize our custom Supabase client
supabase = SupabaseClient()

def get_embedding(text: str, model: str = "nomic-embed-text") -> list[float]:
    """Get embedding from Ollama"""
    try:
        response = requests.post(
            'http://localhost:11434/api/embeddings',
            json={"model": model, "prompt": text}
        )
        return response.json()["embedding"]
    except Exception as e:
        logger.error(f"Error getting embedding for text '{text}': {str(e)}")
        return None

def main():
    # Initialize Supabase client
    supabase_client = SupabaseClient()
    
    # Get all points of interest
    logger.info("Fetching points of interest from Supabase...")
    response = supabase_client.query_table(table_name='points_of_interest')
    
    points = response.data if hasattr(response, 'data') and response.data else []
    
    if not points:
        logger.error("No points of interest found")
        return
    
    logger.info(f"Found {len(points)} points of interest")
    
    # Process each point
    for point in tqdm(points, desc="Generating embeddings"):
        # Create text for embedding
        text_for_embedding = f"{point['name']} {point.get('place_type', '')} {point.get('address', '')}"
        text_for_embedding = text_for_embedding.strip()
        
        # Get embedding
        embedding = get_embedding(text_for_embedding)
        if not embedding:
            continue
            
        # Update point with embedding
        try:
            supabase_client.update_table(
                table_name='points_of_interest',
                data={
                    "embedding": embedding,
                    "updated_at": "now()"
                },
                conditions=[('id', point['id'])]
            )
            logger.debug(f"Updated embedding for {point['name']}")
            
        except Exception as e:
            logger.error(f"Error updating embedding for {point['name']}: {str(e)}")

if __name__ == "__main__":
    main() 