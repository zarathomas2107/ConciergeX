import asyncio
from search_service.agents.preferences_agent import PreferencesAgent

async def test_scenarios():
    # Initialize the agent with service key for direct DB access
    agent = PreferencesAgent(use_service_key=True)
    
    # Test user ID
    user_id = "571cacbe-aba9-407f-bae3-c3acae58db01"
    
    # Define test scenarios
    scenarios = [
        {
            'name': 'Group with cuisine and meal time',
            'query': 'Looking for Indian restaurants for dinner with @Navnit',
            'expected': {
                'group': 'Navnit',
                'cuisine': ['Indian'],
                'meal_time': 'dinner'
            }
        },
        {
            'name': 'Multiple cuisines with group',
            'query': 'Show me Italian or French restaurants for @Navnit',
            'expected': {
                'group': 'Navnit',
                'cuisine': ['Italian', 'French'],
                'meal_time': None
            }
        },
        {
            'name': 'Just cuisine and meal time',
            'query': 'Find Chinese restaurants for lunch',
            'expected': {
                'group': None,
                'cuisine': ['Chinese'],
                'meal_time': 'lunch'
            }
        },
        {
            'name': 'Breakfast query with group',
            'query': 'Looking for breakfast places with @Navnit',
            'expected': {
                'group': 'Navnit',
                'cuisine': None,
                'meal_time': 'breakfast'
            }
        }
    ]
    
    # Run each test scenario
    for scenario in scenarios:
        print(f"\n{'='*70}")
        print(f"Testing Scenario: {scenario['name']}")
        print(f"{'='*70}")
        print(f"Query: {scenario['query']}")
        print(f"Expected Group: {scenario['expected']['group']}")
        print(f"Expected Cuisine: {scenario['expected']['cuisine']}")
        print(f"Expected Meal Time: {scenario['expected']['meal_time']}")
        print(f"{'-'*70}\n")
        
        result = await agent.extract_preferences(scenario['query'], user_id)
        
        print("\nResults:")
        print(f"{'-'*70}")
        print(f"Group: {result.get('group')}")
        print(f"Cuisine Types: {result.get('cuisine_types', [])}")
        print(f"Meal Time: {result.get('meal_time')}")
        print(f"Dietary Requirements: {result.get('dietary_requirements', [])}")
        print(f"Excluded Cuisines: {result.get('excluded_cuisines', [])}")
        print(f"{'='*70}\n")

if __name__ == "__main__":
    asyncio.run(test_scenarios()) 