import pytest
import pytest_asyncio
from ..agents.preferences_agent import PreferencesAgent
import json

@pytest_asyncio.fixture
async def preferences_agent():
    """Create and return a PreferencesAgent instance."""
    agent = PreferencesAgent(use_service_key=True)
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
    input_text = f"user_id: {user_id}\nquery: {query}"
    agent_result = await preferences_agent.agent_executor.ainvoke({
        "input": input_text
    })
    
    # Print the agent's steps in a clearer format
    print("\nAGENT'S TOOL USAGE SEQUENCE:")
    print("="*50)
    for i, step in enumerate(agent_result.get("intermediate_steps", []), 1):
        action = step[0]  # The action the agent took
        print(f"\n[STEP {i}]")
        print("Tool Selected:", action.tool)
        print("Tool Input:", action.tool_input)
        print("Tool Output:", step[1])
        print("-"*50)
    
    result = json.loads(agent_result["output"]) if isinstance(agent_result["output"], str) else agent_result["output"]
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
    input_text = f"user_id: {user_id}\nquery: {query}"
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
    
    result = await preferences_agent.get_group_preferences(user_id, group_name)
    print("\nGroup preferences result:", result)
    
    assert isinstance(result, dict)
    assert "dietary_requirements" in result
    assert isinstance(result["dietary_requirements"], list)
    assert "excluded_cuisines" in result
    assert isinstance(result["excluded_cuisines"], list) 