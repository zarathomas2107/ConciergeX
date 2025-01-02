import asyncio
from search_service.agents.preferences_agent import PreferencesAgent

async def test():
    agent = PreferencesAgent(use_service_key=True)
    result = await agent.get_group_preferences(
        user_id='571cacbe-aba9-407f-bae3-c3acae58db01',
        group_name='Navnit'
    )
    print('Result:', result)

if __name__ == "__main__":
    asyncio.run(test()) 