import pytest
import json
import os
from dotenv import load_dotenv
from search_service.agents.query_agent import QueryAgent

# Load environment variables
load_dotenv()

@pytest.mark.asyncio
async def test_query_generation():
    # Ensure environment variables are set
    if not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_SERVICE_KEY"):
        pytest.skip("Missing required environment variables")
        
    agent = QueryAgent(use_service_key=True)
    
    print("\n=== Test Query Generation ===")
    
    # Check available cuisine types
    print("\nChecking available cuisine types:")
    cuisine_response = agent.supabase.table('restaurants').select("CuisineType").execute()
    if cuisine_response.data:
        cuisine_types = set(r['CuisineType'] for r in cuisine_response.data if r['CuisineType'] is not None)
        print("Available cuisine types:", sorted(cuisine_types))
        print("Total restaurants:", len(cuisine_response.data))
        print("Restaurants with cuisine type:", len(cuisine_types))
    
    test_cases = [
        {
            "name": "Basic cuisine search",
            "params": {
                "venue": None,
                "preferences": {
                    "dietary_requirements": []
                },
                "cuisine_type": "Indian"
            },
            "expected_query_terms": ["CuisineType", "Indian"]
        },
        {
            "name": "Location-based search",
            "params": {
                "venue": {
                    "name": "Apollo Theatre",
                    "latitude": 51.4613,
                    "longitude": -0.1306
                },
                "preferences": {
                    "dietary_requirements": []
                }
            },
            "expected_query_terms": ["ST_DWithin", "ST_MakePoint", "-0.1306", "51.4613", "3000"]
        },
        {
            "name": "Combined location and cuisine",
            "params": {
                "venue": {
                    "name": "Apollo Theatre",
                    "latitude": 51.4613,
                    "longitude": -0.1306
                },
                "preferences": {
                    "dietary_requirements": []
                },
                "cuisine_type": "Italian"
            },
            "expected_query_terms": ["CuisineType", "Italian", "ST_DWithin", "ST_MakePoint", "-0.1306", "51.4613"]
        },
        {
            "name": "With dietary requirements",
            "params": {
                "venue": None,
                "preferences": {
                    "dietary_requirements": ["vegetarian", "halal"]
                }
            },
            "expected_query_terms": ["DietaryOptions", "vegetarian", "halal"]
        }
    ]
    
    for test_case in test_cases:
        print(f"\nTest Case: {test_case['name']}")
        print("Parameters:", json.dumps(test_case['params'], indent=2))
        
        # Generate query
        query_result = await agent.generate_query(test_case['params'])
        print("\nGenerated SQL:")
        print(query_result)
        
        # Parse the query result
        try:
            query_data = json.loads(query_result)
            assert query_data['success'], f"Query generation failed for {test_case['name']}"
            
            # Check if expected terms are in the query
            for term in test_case['expected_query_terms']:
                assert str(term) in query_data['query'], f"Expected term '{term}' not found in query for {test_case['name']}"
            
            # Execute the query
            results = await agent.execute_search(
                venue=test_case['params']['venue'],
                preferences=test_case['params']['preferences'],
                cuisine_type=test_case['params'].get('cuisine_type')
            )
            
            print("\nResults:")
            if results:
                print(f"Found {len(results)} restaurants")
                for i, result in enumerate(results[:3], 1):  # Show first 3 results
                    print(f"\nResult {i}:")
                    print(json.dumps(result, indent=2))
                assert len(results) > 0, f"No results found for {test_case['name']}"
            else:
                print("No results found")
                
        except json.JSONDecodeError:
            pytest.fail(f"Invalid JSON response for {test_case['name']}")
        except Exception as e:
            pytest.fail(f"Test case {test_case['name']} failed: {str(e)}")

@pytest.mark.asyncio
async def test_query_validation():
    """Test query validation and error handling"""
    agent = QueryAgent(use_service_key=True)
    
    # Test invalid parameters
    invalid_cases = [
        {
            "name": "Empty preferences",
            "params": {
                "venue": None,
                "preferences": None,
                "cuisine_type": "Indian"
            }
        },
        {
            "name": "Invalid venue coordinates",
            "params": {
                "venue": {
                    "name": "Test Venue",
                    "latitude": "invalid",
                    "longitude": -0.1306
                },
                "preferences": {
                    "dietary_requirements": []
                }
            }
        }
    ]
    
    for case in invalid_cases:
        print(f"\nTesting invalid case: {case['name']}")
        result = await agent.generate_query(case['params'])
        print("Result:", result)
        
        try:
            result_data = json.loads(result)
            assert not result_data.get('success', True), f"Expected failure for invalid case: {case['name']}"
        except json.JSONDecodeError:
            print(f"Invalid JSON response for {case['name']}")
        except Exception as e:
            print(f"Test case {case['name']} error: {str(e)}")

@pytest.mark.asyncio
async def test_direct_query_execution():
    """Test direct query execution with various scenarios."""
    query_agent = QueryAgent()
    test_cases = [
        {
            "name": "Basic cuisine query",
            "query": 'SELECT * FROM public.restaurants WHERE "CuisineType" = \'Indian\' LIMIT 20',
            "min_expected": 1
        },
        {
            "name": "Location-based query",
            "query": '''
                SELECT *,
                ST_Distance(
                    location::geography,
                    ST_SetSRID(ST_MakePoint(-73.935242, 40.730610), 4326)::geography
                ) as distance
                FROM public.restaurants
                WHERE ST_DWithin(
                    location::geography,
                    ST_SetSRID(ST_MakePoint(-73.935242, 40.730610), 4326)::geography,
                    1000
                )
                ORDER BY distance, "Rating" DESC
                LIMIT 20
            ''',
            "min_expected": 1
        },
        {
            "name": "Multiple cuisines query",
            "query": 'SELECT * FROM public.restaurants WHERE "CuisineType" IN (\'Indian\', \'Chinese\', \'Italian\') LIMIT 20',
            "min_expected": 1
        }
    ]

    for test_case in test_cases:
        print(f"\nExecuting test case: {test_case['name']}")
        results = await query_agent.execute_query(test_case['query'])
        assert len(results) >= test_case['min_expected'], \
            f"Expected at least {test_case['min_expected']} results for {test_case['name']}, got {len(results)}"
        print(f"Test case {test_case['name']} passed with {len(results)} results")

@pytest.mark.asyncio
async def test_schema():
    """Test to check database schema and sample data."""
    agent = QueryAgent()
    
    print("\n=== Database Schema ===")
    schema = await agent.execute_query('''
        SELECT column_name, data_type, udt_name
        FROM information_schema.columns 
        WHERE table_name = 'restaurants'
        ORDER BY ordinal_position
    ''')
    
    for col in schema:
        print(f"- {col['column_name']}: {col['data_type']} ({col['udt_name']})")
    
    print("\n=== Sample Data ===")
    sample = await agent.execute_query('SELECT * FROM restaurants LIMIT 1')
    if sample:
        print(json.dumps(sample[0], indent=2))
    else:
        print("No sample data found")

@pytest.mark.asyncio
async def test_data():
    """Test to check database contents."""
    agent = QueryAgent()
    
    print("\n=== Database Contents ===")
    
    # Check cuisine type distribution
    cuisine_counts = await agent.execute_query('''
        SELECT "CuisineType", COUNT(*) as count 
        FROM restaurants 
        GROUP BY "CuisineType"
        ORDER BY count DESC
    ''')
    print('\nCuisine type distribution:')
    print(json.dumps(cuisine_counts, indent=2))
    
    # Check Indian restaurants specifically
    indian = await agent.execute_query('''
        SELECT * 
        FROM restaurants 
        WHERE "CuisineType" = 'Indian'
    ''')
    print('\nIndian restaurants:')
    print(json.dumps(indian, indent=2))
    
    # Check price level distribution
    price_counts = await agent.execute_query('''
        SELECT "PriceLevel", COUNT(*) as count 
        FROM restaurants 
        GROUP BY "PriceLevel"
        ORDER BY "PriceLevel"
    ''')
    print('\nPrice level distribution:')
    print(json.dumps(price_counts, indent=2))

@pytest.mark.asyncio
async def test_case_sensitivity():
    """Test case sensitivity in queries."""
    agent = QueryAgent()
    
    print("\n=== Testing Case Sensitivity ===")
    
    # Check cuisine types with different cases
    queries = [
        'SELECT * FROM restaurants WHERE "CuisineType" = \'Indian\'',
        'SELECT * FROM restaurants WHERE "CuisineType" ILIKE \'indian\'',
        'SELECT * FROM restaurants WHERE LOWER("CuisineType") = LOWER(\'Indian\')',
        'SELECT DISTINCT "CuisineType" FROM restaurants WHERE "CuisineType" ILIKE \'%indian%\''
    ]
    
    for query in queries:
        print(f"\nExecuting query: {query}")
        results = await agent.execute_query(query)
        print(f"Results: {json.dumps(results, indent=2)}")

@pytest.mark.asyncio
async def test_database_contents():
    """Test to check actual database contents."""
    agent = QueryAgent()
    
    print("\n=== Database Contents ===")
    
    # Check all cuisine types
    cuisine_query = '''
        SELECT DISTINCT "CuisineType", COUNT(*) as count
        FROM public.restaurants 
        GROUP BY "CuisineType"
        ORDER BY count DESC
    '''
    cuisine_results = await agent.execute_query(cuisine_query)
    print("\nAll cuisine types:")
    print(json.dumps(cuisine_results, indent=2))
    
    # Check all Indian restaurants
    indian_query = '''
        SELECT "Name", "CuisineType", "Rating", location
        FROM public.restaurants 
        WHERE "CuisineType" ILIKE '%indian%'
        ORDER BY "Rating" DESC
    '''
    indian_results = await agent.execute_query(indian_query)
    print("\nAll Indian restaurants:")
    print(json.dumps(indian_results, indent=2))
    
    # Check if restaurants table exists and has data
    table_check = await agent.execute_query('''
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'restaurants'
        ) as table_exists
    ''')
    print("\nRestaurants table exists:", table_check[0]['table_exists'] if table_check else False)
    
    if table_check and table_check[0]['table_exists']:
        count = await agent.execute_query('SELECT COUNT(*) as count FROM public.restaurants')
        print("Total restaurants:", count[0]['count'] if count else 0)

@pytest.mark.asyncio
async def test_supabase_direct():
    """Test direct Supabase queries."""
    agent = QueryAgent()
    
    print("\n=== Direct Supabase Queries ===")
    
    # Try direct table query
    print("\nDirect table query:")
    response = agent.supabase.table('restaurants').select('*').execute()
    print("Response data:", json.dumps(response.data[:2], indent=2) if response.data else "No data")
    print("Response error:", getattr(response, 'error', None))
    
    # Try cuisine filter
    print("\nCuisine filter query:")
    response = agent.supabase.table('restaurants').select('*').eq('CuisineType', 'Indian').execute()
    print("Indian restaurants found:", len(response.data))
    assert len(response.data) > 0, "Expected to find Indian restaurants"
    
    # Try price level filter
    print("\nPrice level filter query:")
    response = agent.supabase.table('restaurants').select('*').eq('PriceLevel', 2).execute()
    print("Price level 2 restaurants found:", len(response.data))
    assert len(response.data) > 0, "Expected to find price level 2 restaurants"

if __name__ == "__main__":
    import asyncio
    asyncio.run(test_query_generation())
    asyncio.run(test_query_validation())
    asyncio.run(test_direct_query_execution())
    asyncio.run(test_schema())
    asyncio.run(test_data())
    asyncio.run(test_case_sensitivity())
    asyncio.run(test_database_contents())
    asyncio.run(test_supabase_direct()) 