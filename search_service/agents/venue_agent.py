from typing import Dict, Any
from openai import AsyncOpenAI
from supabase.client import create_client, Client
import os
import json
import asyncio
import logging
from supabase.lib.client_options import ClientOptions
import re

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class VenueAgent:
    def __init__(self):
        options = ClientOptions(
            schema='public',
            headers={},
            postgrest_client_timeout=10
        )
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL", ""),
            os.getenv("SUPABASE_KEY", ""),
            options=options
        )
        self.client = AsyncOpenAI(
            api_key=os.getenv("OPENAI_API_KEY")
        )

    def _normalize_venue_name(self, venue_name: str) -> str:
        """Normalize venue names for better matching."""
        # Convert to lowercase
        name = venue_name.lower()
        
        # For Odeon Leicester Square, use exact name
        if 'odeon leicester square' in name:
            return 'leicester square'
        
        # For other Odeon searches, try both with and without chain name
        if 'odeon' in name and 'leicester square' in name:
            return 'leicester square'
        
        # Handle common chain name variations
        chain_mappings = {
            'vue': 'vue',
            'cineworld': 'cineworld',
            'picturehouse': 'picturehouse',
            'everyman': 'everyman',
            'curzon': 'curzon'
        }
        
        # Don't remove chain names, just normalize them
        for chain, db_chain in chain_mappings.items():
            if chain in name:
                name = name.replace(chain, db_chain)
                break
                
        return name

    async def validate_venue(self, query: str) -> dict:
        """
        Validate a venue from a user query.
        """
        logger.info(f"Processing query: {query}")
        
        # Extract venue info using GPT-4
        venue_info = await self._extract_venue_info(query)
        
        if not venue_info.get('venue_name') or not venue_info.get('venue_type') or venue_info.get('confidence', 0) < 0.5:
            logger.warning("Low confidence in venue extraction")
            return {'error': 'Could not confidently identify venue'}
        
        # Prepare search query based on venue type
        search_query = venue_info['venue_name'].lower()
        if 'odeon' in search_query.lower():
            search_query = 'london leicester square'
        elif 'cineworld' in search_query.lower():
            search_query = 'leicester square'
        else:
            search_query = re.sub(r'\b(odeon|cineworld)\b', '', search_query, flags=re.IGNORECASE).strip()
        
        logger.info(f"Searching for venue: {search_query} (type: {venue_info['venue_type']})")
        
        # Search for venue in database
        try:
            if venue_info['venue_type'] == 'theatre':
                result = self.supabase.rpc('search_theatres', {'search_query': search_query}).execute()
            else:  # cinema
                result = self.supabase.rpc('search_cinemas', {'search_query': search_query}).execute()
            
            if not result.data:
                logger.warning("No venue found in database")
                return {'error': 'Venue not found in database'}
            
            venue = result.data[0]
            logger.info(f"Found {venue_info['venue_type']}: {venue}")
            
            # Convert location coordinates to separate lat/long
            location = venue.get('location', {}).get('coordinates', [0, 0])
            longitude, latitude = location if len(location) == 2 else (0, 0)
            
            return {
                'id': venue.get('id') or venue.get('place_id'),
                'name': venue['name'],
                'type': venue_info['venue_type'],
                **({"chain": venue['chain']} if 'chain' in venue else {}),
                'latitude': latitude,
                'longitude': longitude,
                'address': venue['address'],
                'location_context': venue_info['location_context'],
                'similarity': venue['similarity']
            }
            
        except Exception as e:
            logger.error(f"Error searching for venue: {e}")
            return {'error': str(e)} 

    async def _extract_venue_info(self, query: str) -> dict:
        """
        Extract venue information from a query using GPT-4.
        """
        try:
            completion = await self.client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {
                        "role": "system",
                        "content": """You are a venue information extraction specialist. Your task is to precisely identify and extract venue information from user queries.
                        
                        Format your response as a valid JSON object with these exact fields:
                        {
                            "venue_name": "string, exact name of the venue (e.g., 'Apollo Theatre', 'Odeon Leicester Square')",
                            "venue_type": "string, must be exactly 'theatre' or 'cinema' (no other values allowed)",
                            "confidence": "number between 0 and 1",
                            "location_context": "string, any additional location context"
                        }
                        
                        Example: For "restaurants near Odeon Leicester Square for dinner", respond with:
                        {
                          "venue_name": "London Leicester Square",
                          "venue_type": "cinema",
                          "confidence": 0.95,
                          "location_context": "Leicester Square area"
                        }
                        
                        If no venue is mentioned or the query is empty, respond with:
                        {
                          "venue_name": "",
                          "venue_type": "",
                          "confidence": 0,
                          "location_context": ""
                        }
                        
                        Always respond with valid JSON. Do not include any other text.
                        The venue_type MUST be exactly 'theatre' or 'cinema' - no variations or misspellings allowed."""
                    },
                    {
                        "role": "user",
                        "content": query
                    }
                ]
            )

            try:
                result = json.loads(completion.choices[0].message.content)
                logger.info(f"GPT-4 extraction result: {result}")
                return result
            except json.JSONDecodeError:
                logger.warning("Invalid JSON response from GPT-4")
                return {
                    "venue_name": "",
                    "venue_type": "",
                    "confidence": 0,
                    "location_context": ""
                }
        except Exception as e:
            logger.error(f"Error in GPT-4 extraction: {e}")
            return {
                "venue_name": "",
                "venue_type": "",
                "confidence": 0,
                "location_context": ""
            } 