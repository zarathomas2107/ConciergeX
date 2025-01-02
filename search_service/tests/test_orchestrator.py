import pytest
import os
from dotenv import load_dotenv
from search_service.agents.langchain_orchestrator import LangChainOrchestrator

# Load environment variables
load_dotenv()

# Test constants
TEST_USER_ID = '7ccda55d-7dc6-4359-b873-c5de9fa8ffdf'

@pytest.mark.asyncio
async def test_basic_venue_search():
    """Test basic restaurant search near a venue."""
    if not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_SERVICE_KEY") or not os.getenv("OPENAI_API_KEY"):
        pytest.skip("Missing required environment variables")
    
    orchestrator = LangChainOrchestrator(collect_training_data=False)
    print("\n=== Testing Basic Venue Search ===")
    
    # Test with Apollo Theatre
    query = "Find restaurants near Apollo Theatre"
    print(f"\nQuery: {query}")
    
    result = await orchestrator.process_query(query, user_id=TEST_USER_ID)
    print("\nResult:", result)
    
    assert result["success"] == True, "Query should succeed"
    assert "summary" in result, "Result should contain a summary"
    assert "query" in result, "Result should contain a SQL query"
    assert "parameters" in result, "Result should contain query parameters"
    assert isinstance(result["query"], str), "Query should be a string"
    assert "SELECT" in result["query"], "Query should be a SELECT statement"
    assert "ST_DWithin" in result["query"], "Query should include distance calculation"
    assert "venue_coordinates" in result["parameters"], "Parameters should include venue coordinates"

@pytest.mark.asyncio
async def test_cuisine_specific_search():
    """Test search with specific cuisine type."""
    if not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_SERVICE_KEY") or not os.getenv("OPENAI_API_KEY"):
        pytest.skip("Missing required environment variables")
    
    orchestrator = LangChainOrchestrator(collect_training_data=False)
    print("\n=== Testing Cuisine-Specific Search ===")
    
    # Test with Indian cuisine
    query = "Find Indian restaurants near Apollo Theatre"
    print(f"\nQuery: {query}")
    
    result = await orchestrator.process_query(query, user_id=TEST_USER_ID)
    print("\nResult:", result)
    
    assert result["success"] == True, "Query should succeed"
    assert "summary" in result, "Result should contain a summary"
    assert "query" in result, "Result should contain a SQL query"
    assert "parameters" in result, "Result should contain query parameters"
    assert "CuisineType" in result["query"], "Query should filter by cuisine type"
    assert "Indian" in result["summary"], "Summary should mention Indian cuisine"

@pytest.mark.asyncio
async def test_preference_based_search():
    """Test search with dietary preferences."""
    if not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_SERVICE_KEY") or not os.getenv("OPENAI_API_KEY"):
        pytest.skip("Missing required environment variables")
    
    orchestrator = LangChainOrchestrator(collect_training_data=False)
    print("\n=== Testing Preference-Based Search ===")
    
    # Test with vegetarian preference
    query = "Find vegetarian restaurants near Odeon Leicester Square"
    print(f"\nQuery: {query}")
    
    result = await orchestrator.process_query(query, user_id=TEST_USER_ID)
    print("\nResult:", result)
    
    assert result["success"] == True, "Query should succeed"
    assert "summary" in result, "Result should contain a summary"
    assert "query" in result, "Result should contain a SQL query"
    assert "parameters" in result, "Result should contain query parameters"
    assert "DietaryOptions" in result["query"], "Query should include dietary options"
    assert "vegetarian" in result["summary"].lower(), "Summary should mention vegetarian options"

@pytest.mark.asyncio
async def test_complex_search():
    """Test search combining venue, cuisine, and preferences."""
    if not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_SERVICE_KEY") or not os.getenv("OPENAI_API_KEY"):
        pytest.skip("Missing required environment variables")
    
    orchestrator = LangChainOrchestrator(collect_training_data=False)
    print("\n=== Testing Complex Search ===")
    
    # Test with multiple criteria
    query = "Find affordable Italian restaurants near Apollo Theatre that are family-friendly"
    print(f"\nQuery: {query}")
    
    result = await orchestrator.process_query(query, user_id=TEST_USER_ID)
    print("\nResult:", result)
    
    assert result["success"] == True, "Query should succeed"
    assert "summary" in result, "Result should contain a summary"
    assert "query" in result, "Result should contain a SQL query"
    assert "parameters" in result, "Result should contain query parameters"
    assert "CuisineType" in result["query"], "Query should filter by cuisine type"
    assert "PriceRange" in result["query"], "Query should filter by price range"
    assert "Features" in result["query"], "Query should filter by features"
    assert "Italian" in result["summary"], "Summary should mention Italian cuisine"

@pytest.mark.asyncio
async def test_error_handling():
    """Test error handling with invalid inputs."""
    if not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_SERVICE_KEY") or not os.getenv("OPENAI_API_KEY"):
        pytest.skip("Missing required environment variables")
    
    orchestrator = LangChainOrchestrator(collect_training_data=False)
    print("\n=== Testing Error Handling ===")
    
    # Test with empty query
    query = ""
    print(f"\nQuery: {query}")
    
    result = await orchestrator.process_query(query, user_id=TEST_USER_ID)
    print("\nResult:", result)
    
    assert result["success"] == False, "Empty query should fail"
    assert "summary" in result, "Result should contain a summary"
    assert "error" in result, "Result should contain an error message"
    
    # Test with invalid venue
    query = "Find restaurants near NonexistentVenue123"
    print(f"\nQuery: {query}")
    
    result = await orchestrator.process_query(query, user_id=TEST_USER_ID)
    print("\nResult:", result)
    
    assert "summary" in result, "Result should contain a summary"
    assert "error" in result, "Result should contain an error message" 