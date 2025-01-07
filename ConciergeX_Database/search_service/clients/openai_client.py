import os
from openai import AsyncOpenAI
import logging
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

logger = logging.getLogger(__name__)

class OpenAIClient:
    """Client for handling OpenAI API calls for embeddings and completions."""
    
    def __init__(self, completion_model: str = "gpt-4o-mini", embedding_model: str = "text-embedding-3-small"):
        """Initialize the OpenAI client with API key."""
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable not set")
            
        self.client = AsyncOpenAI(api_key=api_key)
        self.embedding_model = embedding_model
        self.completion_model = completion_model
        
    async def get_embedding(self, text: str | list) -> Optional[List[float]]:
        """Get embedding from OpenAI."""
        try:
            # If text is a list, join it with spaces
            if isinstance(text, list):
                text = " ".join(text)
                
            logger.info(f"Getting embedding for text: '{text}'")
            response = await self.client.embeddings.create(
                model=self.embedding_model,
                input=text,
                encoding_format="float"
            )
            
            embedding = response.data[0].embedding
            logger.debug(f"Successfully obtained embedding of length {len(embedding)}")
            return embedding
            
        except Exception as e:
            logger.error(f"Error getting embedding: {str(e)}", exc_info=True)
            return None
            
    async def get_completion(self, 
                           prompt: str, 
                           system_prompt: str = "",
                           temperature: float = 0.7) -> Optional[Dict[str, Any]]:
        """Get completion from OpenAI."""
        try:
            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            messages.append({"role": "user", "content": prompt})
            
            response = await self.client.chat.completions.create(
                model=self.completion_model,
                messages=messages,
                temperature=temperature
            )
            
            content = response.choices[0].message.content
            
            # Try to find JSON in the content
            import json
            try:
                # First try to parse the whole content
                return json.loads(content)
            except json.JSONDecodeError:
                # If that fails, try to find JSON object or array in the content
                json_start = content.find('{')
                json_end = content.rfind('}')
                array_start = content.find('[')
                array_end = content.rfind(']')
                
                if json_start != -1 and json_end != -1:
                    json_content = content[json_start:json_end + 1]
                elif array_start != -1 and array_end != -1:
                    json_content = content[array_start:array_end + 1]
                else:
                    return {"error": "No JSON found", "raw_content": content}
                    
                try:
                    return json.loads(json_content)
                except json.JSONDecodeError:
                    return {"error": "Failed to parse JSON", "raw_content": content}
                    
        except Exception as e:
            logger.error(f"Error getting completion: {str(e)}", exc_info=True)
            return None 