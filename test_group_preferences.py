import asyncio
from search_service.agents.preferences_agent import PreferencesAgent

async def test_group_preferences():
    # Initialize the agent with service key for direct DB access
    agent = PreferencesAgent(use_service_key=True)
    
    # Test parameters
    user_id = "571cacbe-aba9-407f-bae3-c3acae58db01"  # Example user ID
    group_name = "Navnit"  # The group we want to test
    
    print(f"\n=== Testing get_group_preferences ===")
    print(f"User ID: {user_id}")
    print(f"Group Name: {group_name}")
    print("=" * 50)
    
    # Call the method and get results
    result = await agent.get_group_preferences(user_id, group_name)
    
    print("\nResults:")
    print("-" * 50)
    print(f"Dietary Requirements: {result['dietary_requirements']}")
    print(f"Excluded Cuisines: {result['excluded_cuisines']}")
    print("=" * 50)

if __name__ == "__main__":
    asyncio.run(test_group_preferences()) 