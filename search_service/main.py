# search_service/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from search_service.agents.langchain_orchestrator import LangChainOrchestrator
import uvicorn
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()
orchestrator = LangChainOrchestrator()

class SearchRequest(BaseModel):
    query: str
    user_id: str

@app.post("/search")
async def search(request: SearchRequest):
    try:
        result = await orchestrator.process_query(request.query, request.user_id)
        return result
    except Exception as e:
        logger.error(f"Search error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)