from fastapi import FastAPI, HTTPException, Security, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security.api_key import APIKeyHeader, APIKey
from pydantic import BaseModel
import uvicorn
import os
import logging
from typing import List

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Health check endpoint - completely independent
@app.get("/health")
def health_check():
    logger.info("Health check called")
    return {"status": "healthy"}

# Load environment variables after health check is set up
@app.on_event("startup")
async def startup_event():
    logger.info("=== Starting application with detailed environment check ===")
    # Test environment variables
    required_vars = [
        "API_KEY",
        "OPENAI_API_KEY",
        "SUPABASE_URL",
        "SUPABASE_SERVICE_KEY"
    ]
    
    logger.info("=== Environment Variables ===")
    for var in required_vars:
        value = os.getenv(var)
        if not value:
            logger.error(f"Missing required environment variable: {var}")
        else:
            # Safely log the first and last few characters of sensitive values
            if var in ["API_KEY", "OPENAI_API_KEY", "SUPABASE_SERVICE_KEY"]:
                safe_value = f"{value[:4]}...{value[-4:]}" if len(value) > 8 else "***"
                logger.info(f"Found {var}: {safe_value} (length: {len(value)})")
            else:
                logger.info(f"Found {var}: {value}")
    
    logger.info("=== All Environment Variables ===")
    for key, value in os.environ.items():
        if key in required_vars:
            safe_value = f"{value[:4]}...{value[-4:]}" if len(value) > 8 else "***"
            logger.info(f"ENV: {key}={safe_value}")
    
    logger.info("=== Application startup complete ===")

# CORS configuration - before any routes
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Key authentication
API_KEY_NAME = "X-API-Key"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

async def verify_api_key(api_key: str = Header(..., alias="X-API-Key")) -> str:
    logger.info("=== API Key Validation Start ===")
    logger.info(f"Raw header value: '{api_key}'")
    logger.info(f"Raw env value: '{os.getenv('API_KEY')}'")
    logger.info(f"Header bytes: {[ord(c) for c in api_key]}")
    logger.info(f"Env bytes: {[ord(c) for c in os.getenv('API_KEY', '')]}")
    logger.info(f"Header repr: {repr(api_key)}")
    logger.info(f"Env repr: {repr(os.getenv('API_KEY'))}")
    
    if not api_key or api_key != os.getenv("API_KEY"):
        logger.error("=== API Key Validation Failed ===")
        raise HTTPException(status_code=500, detail="Invalid API key")
    
    logger.info("=== API Key Validation Success ===")
    return api_key

class SearchRequest(BaseModel):
    query: str
    user_id: str

@app.post("/search")
async def search_restaurants(
    request: SearchRequest,
    api_key: APIKey = Depends(verify_api_key)
):
    logger.info(f"Search request received: {request.query}")
    try:
        # Import here to avoid startup delay
        from search_service.agents.restaurant_agent import RestaurantAgent
        agent = RestaurantAgent(use_service_key=True)
        result = await agent.find_restaurants(request.query, request.user_id)
        return result
    except Exception as e:
        logger.error(f"Error in search: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    logger.info(f"Starting server on port {port}")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        proxy_headers=True,
        forwarded_allow_ips="*",
        log_level="info"
    ) 