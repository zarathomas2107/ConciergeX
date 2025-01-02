import os
import json
import requests
from dotenv import load_dotenv

def test_search_restaurants():
    # Load environment variables
    load_dotenv()
    
    # Get Supabase URL and anon key
    supabase_url = os.getenv('SUPABASE_URL')
    supabase_anon_key = os.getenv('SUPABASE_ANON_KEY')
    if not supabase_url or not supabase_anon_key:
        raise ValueError("SUPABASE_URL and SUPABASE_ANON_KEY environment variables must be set")

    # Test queries
    test_cases = [
        {
            "name": "Basic restaurant search",
            "query": "Find Italian restaurants",
            "expected_terms": ["Italian", "restaurants"]
        },
        {
            "name": "Location-based search",
            "query": "Find restaurants near Apollo Theatre",
            "expected_terms": ["Apollo Theatre", "distance"]
        },
        {
            "name": "Combined search",
            "query": "Find high-rated Indian restaurants near Covent Garden",
            "expected_terms": ["Indian", "Covent Garden", "Rating"]
        }
    ]

    # Function URL
    function_url = f"{supabase_url}/functions/v1/search-restaurants"
    
    # Test user ID
    test_user_id = "7ccda55d-7dc6-4359-b873-c5de9fa8ffdf"

    print("\nTesting search-restaurants function...")
    
    for test_case in test_cases:
        print(f"\nTest case: {test_case['name']}")
        print(f"Query: {test_case['query']}")
        
        try:
            # Make request to the function
            response = requests.post(
                function_url,
                headers={
                    'Content-Type': 'application/json',
                    'Authorization': f'Bearer {supabase_anon_key}',
                },
                json={
                    'query': test_case['query'],
                    'user_id': test_user_id
                }
            )
            
            # Print response status
            print(f"Status code: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                print(f"Success: {result.get('success', False)}")
                print(f"Summary: {result.get('summary', '')}")
                
                restaurants = result.get('restaurants', [])
                print(f"Found {len(restaurants)} restaurants")
                
                if restaurants:
                    print("\nFirst restaurant:")
                    first = restaurants[0]
                    print(f"Name: {first.get('Name')}")
                    print(f"Cuisine: {first.get('CuisineType')}")
                    print(f"Rating: {first.get('Rating')}")
                    print(f"Address: {first.get('Address')}")
                    if 'distance' in first:
                        print(f"Distance: {first.get('distance')}m")
            else:
                print(f"Error: {response.text}")
                
        except Exception as e:
            print(f"Error: {str(e)}")
        
        print("-" * 50)

if __name__ == "__main__":
    test_search_restaurants() 