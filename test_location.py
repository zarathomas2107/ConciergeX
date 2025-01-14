import os
import sys
import asyncio

# Set up environment variables
os.environ["SUPABASE_KEY"] = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

# Add the correct path
sys.path.append(os.path.join(os.path.dirname(__file__), "ConciergeX_Database/search_service"))
from agents.location_detection import LocationDetectionAgent

async def test():
    agent = LocationDetectionAgent()
    
    test_queries = [
        # Central London
        'Restaurants in Mayfair',
        'Dinner in Soho',
        'Lunch near Oxford Circus',
        'Food near Covent Garden',
        
        # East London
        'Restaurants in Shoreditch',
        'Dinner in Brick Lane',
        'Places near Spitalfields Market',
        'Food in Hoxton',
        
        # West London
        'Restaurants in Notting Hill',
        'Dinner in Chelsea',
        'Places near Westfield White City',
        'Food in Shepherds Bush',
        
        # North London
        'Restaurants in Camden Town',
        'Dinner in Islington',
        'Places near Emirates Stadium',
        'Food in Angel',
        
        # South London
        'Restaurants in Brixton',
        'Dinner in Peckham',
        'Places near Borough Market',
        'Food in Greenwich'
    ]
    
    for query in test_queries:
        print(f'\n{"="*50}')
        print(f'Testing query: {query}')
        print(f'{"="*50}')
        
        terms = await agent.extract_terms(query)
        print(f'Extracted terms: {terms}')

if __name__ == "__main__":
    asyncio.run(test()) 