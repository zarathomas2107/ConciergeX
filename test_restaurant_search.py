import asyncio
from search_service.agents.restaurant_agent import RestaurantAgent

def format_distance(meters: float) -> str:
    """Format distance in meters to a human-readable string"""
    if meters < 1000:
        return f"{int(meters)}m"
    else:
        return f"{meters/1000:.1f}km"

async def print_results(result: dict, scenario_name: str):
    print(f"\n=== {scenario_name} ===")
    print("=" * 50)
    
    if 'error' in result:
        print(f"\nError: {result['error']}")
        return
        
    # Print venue information
    print("\nVenue Information:")
    print("-" * 50)
    venue = result['venue']
    print(f"Name: {venue['name']}")
    print(f"Type: {venue['type']}")
    print(f"Location: {venue['latitude']}, {venue['longitude']}")
    print(f"Address: {venue['address']}")
    
    # Print preferences
    print("\nExtracted Preferences:")
    print("-" * 50)
    prefs = result['preferences']
    print(f"Group: {prefs.get('group')}")
    print(f"Excluded Cuisines: {prefs.get('excluded_cuisines', [])}")
    print(f"Dietary Requirements: {prefs.get('dietary_requirements', [])}")
    
    # Print restaurant results
    print("\nRestaurants Found:")
    print("-" * 50)
    restaurants = result['restaurants']
    print(f"Total restaurants found: {len(restaurants)}")
    
    if restaurants:
        print("\nTop 30 Matches:")
        for i, rest in enumerate(restaurants[:30], 1):
            distance = rest.get('distance_meters')
            distance_str = format_distance(distance) if distance is not None else 'N/A'
            
            print(f"\n{i}. {rest['name']}")
            print(f"   Cuisine: {rest.get('cuisine_type', 'N/A')}")
            print(f"   Rating: {rest.get('rating', 'N/A')}")
            print(f"   Distance from venue: {distance_str}")
            print(f"   Address: {rest.get('address', 'N/A')}")

async def test_restaurant_search():
    # Initialize the agent with service key for direct DB access
    agent = RestaurantAgent(use_service_key=True)
    
    # Test parameters
    user_id = "571cacbe-aba9-407f-bae3-c3acae58db01"
    
    # Test Scenario 1: Regular search
    query1 = "Looking for restaurants near Odeon Leicester Square but not French or Steakhouse"
    result1 = await agent.find_restaurants(query1, user_id)
    await print_results(result1, "Regular Search")
    
    # Test Scenario 2: Group search with Navnit
    query2 = "Looking for restaurants near Odeon Leicester Square with @Navnit"
    result2 = await agent.find_restaurants(query2, user_id)
    await print_results(result2, "Group Search with @Navnit")

if __name__ == "__main__":
    asyncio.run(test_restaurant_search()) 