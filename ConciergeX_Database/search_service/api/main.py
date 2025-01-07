from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Any
from search_service.agents.restaurant_agent import RestaurantAgent
import logging
import uvicorn
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Restaurant Search API",
    description="API for processing restaurant search queries with location, time, and preference detection",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Initialize the agent
agent = RestaurantAgent()

class SearchRequest(BaseModel):
    query: str
    user_id: str

class ErrorResponse(BaseModel):
    detail: str

@app.post("/search", response_model=Dict[str, Any], responses={500: {"model": ErrorResponse}})
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
        results = await agent.process_query(request.query, request.user_id)
        return results
    except Exception as e:
        logger.error(f"Error processing query: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}

if __name__ == "__main__":
    # Get port from environment variable or default to 8080
    port = int(os.environ.get("PORT", 8080))
    # Use 0.0.0.0 to bind to all interfaces
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False) 