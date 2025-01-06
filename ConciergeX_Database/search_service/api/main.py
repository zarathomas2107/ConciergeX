from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Dict, Any
from search_service.agents.restaurant_agent import RestaurantAgent
import logging
import uvicorn

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Restaurant Search API")

# Initialize the agent
agent = RestaurantAgent()

class SearchRequest(BaseModel):
    query: str
    user_id: str

@app.post("/search")
async def search_restaurants(request: SearchRequest) -> Dict[str, Any]:
    """
    Process a restaurant search query and return recommendations.
    
    Args:
        request: SearchRequest containing:
            - query: The search query (e.g., "Italian Restaurant with @Family in April")
            - user_id: The ID of the user making the request
            
    Returns:
        Dict containing:
            - preferences: dietary requirements and cuisine types
            - location: venue ID, name, and address
            - datetime: timing preferences
    """
    try:
        results = agent.process_query(request.query, request.user_id)
        return results
    except Exception as e:
        logger.error(f"Error processing query: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True) 