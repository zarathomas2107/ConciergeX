import os
import sys
import asyncio
import dotenv
from agents.preferences_agent import PreferencesAgent

# Load environment variables
dotenv.load_dotenv()

async def test_get_group_preferences():
    # Initialize the agent
    agent = PreferencesAgent()
    
    # Test parameters
    user_id = "a196d6e8-1e2e-4ded-a63c-37f4a18dc1d1"
    group_name = "Jim"
    
    try:
        preferences = await agent.get_group_preferences(group_name, user_id)
        print(f"\nPreferences for group {group_name}:")
        print(f"Dietary requirements: {preferences.get('dietary_requirements', [])}")
        print(f"Excluded cuisines: {preferences.get('excluded_cuisines', [])}")
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    asyncio.run(test_get_group_preferences()) 