import os
import sys
import asyncio

# Add the correct path
sys.path.append(os.path.join(os.path.dirname(__file__), "ConciergeX_Database/search_service"))
from agents.restaurant_agent import RestaurantAgent

async def test():
    agent = RestaurantAgent()
    
    test_queries = [
        # Test different cuisines and locations
        {
            "query": "Italian restaurants in Mayfair with @Jim",
            "user_id": "a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1"
        },
        {
            "query": "Japanese food near Shoreditch for dinner with @Navnit",
            "user_id": "a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1"
        },
        {
            "query": "Vegetarian places in Covent Garden",
            "user_id": "a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1"
        },
        {
            "query": "Lunch spots near Oxford Circus with @Family",
            "user_id": "a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1"
        },
        {
            "query": "Indian restaurants in Brick Lane for tomorrow",
            "user_id": "a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1"
        }
    ]
    
    for test_case in test_queries:
        print(f'\n{"="*50}')
        print(f'Testing query: {test_case["query"]}')
        print(f'{"="*50}')
        
        result = await agent.process_query(test_case["query"], test_case["user_id"])
        print(f'Result: {result}')

if __name__ == "__main__":
    asyncio.run(test()) 