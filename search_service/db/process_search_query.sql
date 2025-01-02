CREATE OR REPLACE FUNCTION process_search_query(
  query_text TEXT,
  user_id_input UUID
)
RETURNS JSON
LANGUAGE plpython3u
AS $$
import json
import sys
import os

# Add the search_service directory to Python path
sys.path.append('/var/lib/postgresql/search_service')

try:
    from agents.langchain_orchestrator import LangChainOrchestrator
    
    # Initialize the orchestrator
    orchestrator = LangChainOrchestrator()
    
    # Process the query
    result = orchestrator.process_query(query_text, str(user_id_input))
    
    # Return the result as JSON
    return json.dumps({
        'sql_query': result.get('query', ''),
        'parameters': result.get('parameters', {}),
        'summary': result.get('summary', '')
    })
    
except Exception as e:
    plpy.error(f"Error processing search query: {str(e)}")
$$; 