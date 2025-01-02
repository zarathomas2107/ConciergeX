import asyncio
import json
from search_service.agents.langchain_orchestrator import LangChainOrchestrator
from supabase import create_client
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

async def test_sql_query(query_string: str):
    """Test running a SQL query directly against Supabase"""
    
    # Initialize Supabase client
    supabase = create_client(
        os.getenv("SUPABASE_URL"),
        os.getenv("SUPABASE_KEY")
    )
    
    print("\n🔍 Testing SQL query:")
    print("-" * 80)
    print(query_string)
    print("-" * 80)
    
    try:
        # Execute query using RPC
        response = supabase.rpc(
            'filter_restaurants',
            {
                'query_string': query_string
            }
        ).execute()
        
        print("\n📝 Results:")
        if response.data:
            for restaurant in response.data:
                print(f"- {restaurant['Name']} ({restaurant['CuisineType']})")
                print(f"  Rating: {restaurant['Rating']}, Address: {restaurant['Address']}")
                print()
        else:
            print("No restaurants found")
            
        print(f"\nTotal results: {len(response.data) if response.data else 0}")
        return response.data
        
    except Exception as e:
        print(f"\n❌ Error executing query: {e}")
        return None

async def run_test_query(query: str):
    """Run a single test query through the orchestrator"""
    print(f"\n🔍 Testing query: {query}")
    print("-" * 80)
    
    # Initialize orchestrator
    orchestrator = LangChainOrchestrator(collect_training_data=False)
    
    # Process query
    result = await orchestrator.process_query(query)
    
    # Pretty print result
    print("\n📝 LLM Result:")
    print(json.dumps(result, indent=2))
    print("-" * 80)
    
    # If we got a valid query, test it
    if result.get("success") and result.get("query"):
        print("\n🔍 Testing generated SQL:")
        restaurants = await test_sql_query(result["query"])
        if restaurants:
            result["restaurants"] = restaurants
    
    return result

async def test_basic_search():
    """Test basic restaurant search near a venue"""
    query = "Find Italian restaurants near Apollo Theatre"
    return await run_test_query(query)

async def test_preferences_search():
    """Test search with preferences"""
    query = "Find family-friendly restaurants near Lyceum Theatre with outdoor seating"
    return await run_test_query(query)

async def test_complex_search():
    """Test complex search with multiple criteria"""
    query = "Find affordable Asian restaurants near Covent Garden that are good for groups and have vegetarian options"
    return await run_test_query(query)

async def main():
    # Choose which test to run
    await test_basic_search()
    # await test_preferences_search()
    # await test_complex_search()

if __name__ == "__main__":
    asyncio.run(main()) 