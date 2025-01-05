import json
import logging
from typing import Dict, Optional, Union, Any
import requests
import asyncio

logger = logging.getLogger(__name__)

class LlamaAgent:
    def __init__(self, model_size: str = None):
        self.ollama_endpoint = "http://localhost:11434/api/generate"
        self.model = "llama3:latest"
        
    def get_completion(self, prompt: str, system_prompt: str = "") -> Optional[Dict]:
        """Get a completion from the Llama model using Ollama.
        
        Args:
            prompt: The user prompt to send to the model
            system_prompt: Optional system prompt to prepend
            
        Returns:
            Dict: The parsed JSON response from the model, or None if parsing fails
        """
        try:
            # Prepare the request to Ollama
            data = {
                "model": self.model,
                "prompt": f"{system_prompt}\n\n{prompt}" if system_prompt else prompt,
                "stream": False
            }
            
            # Make the request to Ollama
            response = requests.post(self.ollama_endpoint, json=data)
            if response.status_code == 200:
                # Extract the response text
                response_text = response.json()['response']
                
                # Try to parse the JSON response
                try:
                    # Find the JSON part in the response (in case there's any extra text)
                    json_start = response_text.find('{')
                    json_end = response_text.rfind('}') + 1
                    if json_start >= 0 and json_end > json_start:
                        json_str = response_text[json_start:json_end]
                        return json.loads(json_str)
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse JSON response: {e}")
                except Exception as e:
                    logger.error(f"Error processing response: {e}")
                
                # If JSON parsing fails, return the raw response text as a dict
                return {"response": response_text}
            
            logger.error(f"Error from Ollama API: {response.text}")
            return None
            
        except Exception as e:
            logger.error(f"Error getting completion from Llama: {e}")
            return None

    async def _generate_response(self, prompt: str, system_prompt: str = "") -> Union[Dict[str, Any], str]:
        """Async wrapper around get_completion for compatibility with existing agents."""
        # Run get_completion in a thread pool since it makes blocking HTTP requests
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, self.get_completion, prompt, system_prompt)
        return result 