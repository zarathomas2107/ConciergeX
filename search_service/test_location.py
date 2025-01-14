import os
import sys
import asyncio
import logging

# Add the search_service directory to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)

from agents.location_detection import LocationDetectionAgent

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_locations():
    agent = LocationDetectionAgent()
    
    test_queries = [
        'Italian restaurants near the O2 Arena',
        'Dinner at the Shard with @Jim',
        'Lunch near Canary Wharf station',
        'Restaurants near the Google office in Kings Cross',
        'Places to eat in Westfield Stratford',
        'Restaurants in Hackney',
        'Food near Excel Centre',
        'Dinner in Shoreditch High Street',
        'Places near Liverpool Street Station',
        'Restaurants near Databricks office in London'
    ]
    
    for query in test_queries:
        try:
            print(f'\n{"="*50}')
            print(f'Testing query: {query}')
            print(f'{"="*50}')
            
            print('Extracting terms...')
            terms = await agent.extract_terms(query)
            print(f'Extracted terms: {terms}')
            
            print('\nDetecting location...')
            location = await agent.detect_location(query)
            print(f'Final location: {location}')
            
        except Exception as e:
            print(f'Error processing query "{query}": {str(e)}')

if __name__ == "__main__":
    asyncio.run(test_locations()) 