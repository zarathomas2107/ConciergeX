import asyncio
import pytest
from search_service.agents.venue_agent import VenueAgent
import logging
import os
from dotenv import load_dotenv
from pathlib import Path
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables from the root directory
env_path = Path(__file__).parents[2] / '.env'
load_dotenv(dotenv_path=env_path)

# Verify environment variables
required_vars = ['SUPABASE_URL', 'SUPABASE_KEY', 'OPENAI_API_KEY']
missing_vars = [var for var in required_vars if not os.getenv(var)]
if missing_vars:
    raise EnvironmentError(f"Missing required environment variables: {', '.join(missing_vars)}")

@pytest.mark.asyncio
async def test_venue_validation():
    agent = VenueAgent()
    test_cases = [
        {
            "query": "Find restaurants near Apollo Theatre",
            "expected_name": "Apollo Theatre",
            "expected_type": "theatre"
        },
        {
            "query": "Looking for food near Odeon Leicester Square",
            "expected_name": "London Leicester Square",
            "expected_type": "cinema"
        },
        {
            "query": "Places to eat around Leicester Square Odeon",
            "expected_name": "London Leicester Square",
            "expected_type": "cinema"
        },
        {
            "query": "Dinner options near the Odeon in Leicester Square",
            "expected_name": "London Leicester Square",
            "expected_type": "cinema"
        }
    ]

    print("\n=== Testing Venue Validation ===")
    for case in test_cases:
        print(f"\n--- Test Case ---")
        print(f"Input Query: {case['query']}")
        print(f"Expected Name: {case['expected_name']}")
        print(f"Expected Type: {case['expected_type']}")
        
        result = await agent.validate_venue(case["query"])
        
        print("\nResult:")
        print(json.dumps(result, indent=2))
        
        if 'error' in result:
            print(f"❌ Error in validation: {result['error']}")
            assert False, f"Validation failed with error: {result['error']}"
        
        # Verify results
        assert result['name'] == case['expected_name'], \
            f"Expected venue name {case['expected_name']}, got {result['name']}"
        assert 'latitude' in result and 'longitude' in result, \
            "Location coordinates missing from result"
        assert 'address' in result, "Address missing from result"
        assert 'similarity' in result, "Similarity score missing from result"
        assert result['similarity'] > 0.2, "Similarity score too low"
        
        print("✅ Test case passed")

@pytest.mark.asyncio
async def test_error_handling():
    agent = VenueAgent()
    test_cases = [
        "",  # Empty query
        "No venue mentioned here",  # Query without venue
        "Some random text without any theatre or cinema"  # Invalid query
    ]

    print("\n=== Testing Error Handling ===")
    for query in test_cases:
        print(f"\n--- Test Case ---")
        print(f"Input Query: '{query}'")
        
        result = await agent.validate_venue(query)
        
        print("\nResult:")
        print(json.dumps(result, indent=2))
        
        assert 'error' in result, f"Expected error for invalid query: {query}"
        print("✅ Error handled correctly")

if __name__ == "__main__":
    pytest.main(["-v", "-s", __file__]) 