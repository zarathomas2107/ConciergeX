import asyncio
from search_service.agents.restaurant_agent import RestaurantAgent
import json

async def test_single_search():
    # Initialize the agent
    agent = RestaurantAgent(use_service_key=True)
    
    # Test parameters
    user_id = "571cacbe-aba9-407f-bae3-c3acae58db01"
    query = "Looking for Italian restaurants near Odeon Leicester Square with @Navnit for dinner"
    
    print("\n=== Testing Restaurant Search ===")
    print(f"Query: {query}")
    print(f"User ID: {user_id}")
    print("=" * 50)
    
    # Get results
    result = await agent.find_restaurants(query, user_id)
    
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
    print(f"Cuisine Types: {prefs.get('cuisine_types', [])}")
    print(f"Meal Time: {prefs.get('meal_time')}")
    print(f"Dietary Requirements: {prefs.get('dietary_requirements', [])}")
    print(f"Excluded Cuisines: {prefs.get('excluded_cuisines', [])}")
    
    # Print restaurant results
    print("\nRestaurants Found:")
    print("-" * 50)
    restaurants = result['restaurants']
    print(f"Total restaurants found: {len(restaurants)}")
    
    if restaurants:
        print("\nTop 5 Matches:")
        for i, rest in enumerate(restaurants[:5], 1):
            print(f"\n{i}. {rest['name']}")
            print(f"   Cuisine: {rest.get('cuisine_type', 'N/A')}")
            print(f"   Rating: {rest.get('rating', 'N/A')}")
            print(f"   Distance: {rest.get('distance_meters', 'N/A')}m")
            print(f"   Address: {rest.get('address', 'N/A')}")

if __name__ == "__main__":
    asyncio.run(test_single_search()) 