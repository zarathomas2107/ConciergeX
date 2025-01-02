#!/usr/bin/env python3

import os
import sys
import asyncio
from dotenv import load_dotenv

# Add the parent directory to Python path so we can import search_service
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

# Load environment variables
load_dotenv()

# Import and run tests
from search_service.tests.test_orchestrator import main

if __name__ == "__main__":
    # Verify required environment variables
    required_vars = ["OPENAI_API_KEY", "SUPABASE_URL", "SUPABASE_KEY"]
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        print("Error: Missing required environment variables:")
        for var in missing_vars:
            print(f"- {var}")
        sys.exit(1)
    
    print("Running orchestrator tests...")
    
    # Run the async main function
    asyncio.run(main()) 