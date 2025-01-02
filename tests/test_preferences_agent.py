import pytest
import pytest_asyncio
from search_service.agents.preferences_agent import PreferencesAgent
import json

@pytest_asyncio.fixture
async def preferences_agent():
    """Create and return a PreferencesAgent instance."""
    agent = PreferencesAgent(use_service_key=True)  # Using service key for database access
    return agent

@pytest.mark.asyncio
async def test_extract_preferences_with_group(preferences_agent):
    """Test extracting preferences when a group is mentioned"""
    query = "Looking for Indian restaurants for dinner with @Navnit"
    user_id = "571cacbe-aba9-407f-bae3-c3acae58db01"
    
    print("\n" + "="*50)
    print("TEST: Extract Preferences With Group")
    print("="*50)
    print(f"Query: {query}")
    print(f"User ID: {user_id}")
    print("-"*50)
    
    # Execute the agent with the query and capture the result
    result = await preferences_agent.extract_preferences(query, user_id)
    print("\nFINAL RESULT:")
    print("="*50)
    print(json.dumps(result, indent=2))
    print("="*50)
    
    assert isinstance(result, dict)
    assert "group" in result
    assert result["group"] == "Navnit"
    assert "cuisine_types" in result
    assert "indian" in [c.lower() for c in result["cuisine_types"]]
    assert result["meal_time"] == "dinner"
    assert "dietary_requirements" in result
    assert "excluded_cuisines" in result

@pytest.mark.asyncio
async def test_extract_preferences_without_group(preferences_agent):
    """Test extracting preferences when no group is mentioned"""
    query = "Any good Chinese restaurants for lunch?"
    user_id = "571cacbe-aba9-407f-bae3-c3acae58db01"
    
    print("\n" + "="*50)
    print("TEST: Extract Preferences Without Group")
    print("="*50)
    print(f"Query: {query}")
    print(f"User ID: {user_id}")
    print("-"*50)
    
    # Execute the agent with the query and capture the result
    result = await preferences_agent.extract_preferences(query, user_id)
    print("\nFINAL RESULT:")
    print("="*50)
    print(json.dumps(result, indent=2))
    print("="*50)
    
    assert isinstance(result, dict)
    assert "group" in result
    assert result["group"] is None
    assert "cuisine_types" in result
    assert "chinese" in [c.lower() for c in result["cuisine_types"]]
    assert result["meal_time"] == "lunch"
    assert "dietary_requirements" in result
    assert "excluded_cuisines" in result

@pytest.mark.asyncio
async def test_get_user_requirements(preferences_agent):
    """Test getting user requirements directly"""
    user_id = "571cacbe-aba9-407f-bae3-c3acae58db01"
    
    print("\n=== Testing get_user_requirements ===")
    print(f"User ID: {user_id}")
    
    result = await preferences_agent.get_user_requirements(user_id)
    print("\nUser requirements result:", result)
    
    assert isinstance(result, dict)
    assert "dietary_requirements" in result
    assert isinstance(result["dietary_requirements"], list)
    assert "excluded_cuisines" in result
    assert isinstance(result["excluded_cuisines"], list)

@pytest.mark.asyncio
async def test_get_group_preferences(preferences_agent):
    """Test getting group preferences directly"""
    user_id = "571cacbe-aba9-407f-bae3-c3acae58db01"
    group_name = "Navnit"
    
    print("\n=== Testing get_group_preferences ===")
    print(f"User ID: {user_id}")
    print(f"Group Name: {group_name}")
    print("="*50)
    
    result = await preferences_agent.get_group_preferences(user_id, group_name)
    print("\nResults:")
    print("-"*50)
    print(f"Dietary Requirements: {result['dietary_requirements']}")
    print(f"Excluded Cuisines: {result['excluded_cuisines']}")
    print("="*50)
    
    assert isinstance(result, dict)
    assert "dietary_requirements" in result
    assert isinstance(result["dietary_requirements"], list)
    assert "excluded_cuisines" in result
    assert isinstance(result["excluded_cuisines"], list) 