import os
import sys
import asyncio
import dotenv
from agents.restaurant_agent import RestaurantAgent

# Load environment variables
dotenv.load_dotenv()

async def test_restaurant_agent():
    # Initialize the agent
    agent = RestaurantAgent()
    
    # Test case 1: Group query with location and time
    query = "Looking for italian dinner with @Jim in Shoreditch next Friday"
    user_id = "a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1"
    
    print("\nTest Case 1:")
    print(f"Query: {query}")
    print(f"User ID: {user_id}")
    
    try:
        result = await agent.process_query(query, user_id)
        print("\nResult:")
        print(result)
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    asyncio.run(test_restaurant_agent()) 