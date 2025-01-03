import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any
from .llama_agent import LlamaAgent

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DateTimeAgent(LlamaAgent):
    def __init__(self):
        super().__init__(model_size="8b")  # Using the 8B parameter model
        
        # Define meal times and their contexts
        self.meal_contexts = {
            "breakfast": "morning",
            "lunch": "afternoon",
            "dinner": "evening",
            "brunch": "morning"
        }
        
        # Use today's date
        self.base_date = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)

    def _calculate_date_range(self, day_context: str) -> tuple[str, str]:
        """Calculate start and end dates based on day context."""
        today = self.base_date
        
        if day_context == "today" or day_context == "tonight":
            return today.strftime('%Y-%m-%d'), today.strftime('%Y-%m-%d')
        elif day_context == "tomorrow":
            tomorrow = today + timedelta(days=1)
            return tomorrow.strftime('%Y-%m-%d'), tomorrow.strftime('%Y-%m-%d')
        elif day_context == "next week":
            # Calculate the start of next week (Monday)
            days_until_monday = (7 - today.weekday()) % 7
            if days_until_monday == 0:
                days_until_monday = 7
            start_date = today + timedelta(days=days_until_monday)
            end_date = start_date + timedelta(days=6)  # End of next week (Sunday)
            return start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')
        elif day_context == "this weekend":
            # Calculate upcoming Saturday and Sunday
            days_until_saturday = (5 - today.weekday()) % 7
            if days_until_saturday == 0:
                days_until_saturday = 7
            start_date = today + timedelta(days=days_until_saturday)
            end_date = start_date + timedelta(days=1)  # Sunday
            return start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')
        elif day_context == "this month":
            # Calculate remaining days in current month
            next_month = today.replace(day=28) + timedelta(days=4)
            end_date = next_month - timedelta(days=next_month.day)
            return today.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')
        
        return "", ""

    def _infer_time_context(self, query: str, result: Dict[str, Any]) -> str:
        """Infer time context from query and current result."""
        query = query.lower()
        
        # Check for meal-related contexts
        for meal, context in self.meal_contexts.items():
            if meal in query:
                return context
                
        # Check for specific time periods
        if "tonight" in query or "evening" in query or "dinner" in query:
            return "evening"
        elif "afternoon" in query or "lunch" in query:
            return "afternoon"
        elif "morning" in query or "breakfast" in query:
            return "morning"
            
        # Return existing time context if present
        return result.get('time_context', '')

    async def extract_datetime_info(self, query: str) -> Dict[str, Any]:
        """Extract datetime information from the query."""
        try:
            # Generate response using Llama
            system_prompt = """You are a datetime extraction specialist. Your task is to extract date and time information from user queries.

Format your response as a valid JSON object with these exact fields:
{
    "is_specific_date": boolean,
    "is_specific_time": boolean,
    "start_date": "YYYY-MM-DD or empty string",
    "end_date": "YYYY-MM-DD or empty string",
    "start_time": "HH:MM or empty string",
    "end_time": "HH:MM or empty string",
    "day_context": "string (today/tonight/tomorrow/next week/this weekend/this month/empty string)",
    "time_context": "string (breakfast/lunch/dinner/empty string)",
    "confidence": number between 0 and 1
}

IMPORTANT RULES:
1. Only extract datetime information that is EXPLICITLY mentioned
2. Set is_specific_date=true ONLY for exact dates or single-day references (today, tomorrow, tonight)
   Set is_specific_date=false for date ranges (next week, this weekend, this month)
3. Set is_specific_time=true ONLY when an exact time is mentioned (e.g., "7pm", "19:00")
   Set is_specific_time=false for meal references without a time (e.g., "dinner", "lunch")
4. Use empty strings for fields with no information
5. Set confidence based on how explicit the datetime information is:
   - 0.9+ for exact date and time
   - 0.7-0.8 for clear but incomplete datetime
   - 0.5-0.6 for vague datetime references
   - 0.1-0.2 for queries with no datetime information
6. For time ranges, set both start_time and end_time
7. For date ranges, set both start_date and end_date
8. Convert 12-hour times to 24-hour format (e.g., "7pm" -> "19:00")
9. For empty or meaningless queries, return empty strings with confidence 0.1
10. For time context:
    - Use "breakfast" for morning/early day (before noon)
    - Use "lunch" for midday (noon to 5pm)
    - Use "dinner" for evening/late day (after 5pm)
11. IMPORTANT: Return ONLY the JSON object, no comments or explanations

Example responses:
1. "dinner tonight at 7pm" ->
{
    "is_specific_date": true,
    "is_specific_time": true,
    "start_date": "",
    "end_date": "",
    "start_time": "19:00",
    "end_time": "21:00",
    "day_context": "tonight",
    "time_context": "dinner",
    "confidence": 0.9
}

2. "lunch next week" ->
{
    "is_specific_date": false,
    "is_specific_time": false,
    "start_date": "",
    "end_date": "",
    "start_time": "",
    "end_time": "",
    "day_context": "next week",
    "time_context": "lunch",
    "confidence": 0.7
}

3. "dinner this weekend" ->
{
    "is_specific_date": false,
    "is_specific_time": false,
    "start_date": "",
    "end_date": "",
    "start_time": "",
    "end_time": "",
    "day_context": "this weekend",
    "time_context": "dinner",
    "confidence": 0.6
}

4. "dinner tonight" ->
{
    "is_specific_date": true,
    "is_specific_time": false,
    "start_date": "",
    "end_date": "",
    "start_time": "",
    "end_time": "",
    "day_context": "tonight",
    "time_context": "dinner",
    "confidence": 0.8
}"""

            response = await self._generate_response(query, system_prompt)
            
            try:
                if isinstance(response, dict):
                    datetime_info = response
                else:
                    datetime_info = json.loads(response)
                
                # Calculate date ranges for relative references
                if datetime_info.get('day_context'):
                    start_date, end_date = self._calculate_date_range(datetime_info['day_context'])
                    if start_date:
                        datetime_info['start_date'] = start_date
                    if end_date:
                        datetime_info['end_date'] = end_date
                
                # Add a 2-hour window for specific times
                if datetime_info.get('start_time') and not datetime_info.get('end_time'):
                    try:
                        start_time = datetime.strptime(datetime_info['start_time'], '%H:%M')
                        end_time = start_time + timedelta(hours=2)
                        datetime_info['end_time'] = end_time.strftime('%H:%M')
                    except ValueError:
                        pass
                
                # Ensure time context is set correctly
                if not datetime_info.get('time_context'):
                    datetime_info['time_context'] = self._infer_time_context(query, datetime_info)
                
                # Set confidence to very low for queries without any datetime information
                if not any([datetime_info.get('start_date'), datetime_info.get('end_date'), 
                           datetime_info.get('start_time'), datetime_info.get('end_time'),
                           datetime_info.get('day_context'), datetime_info.get('time_context')]):
                    datetime_info['confidence'] = 0.1
                    
                # Ensure all required fields are present
                datetime_info.setdefault('is_specific_date', False)
                datetime_info.setdefault('is_specific_time', False)
                datetime_info.setdefault('start_date', '')
                datetime_info.setdefault('end_date', '')
                datetime_info.setdefault('start_time', '')
                datetime_info.setdefault('end_time', '')
                datetime_info.setdefault('day_context', '')
                datetime_info.setdefault('time_context', '')
                datetime_info.setdefault('confidence', 0.1)
                
                return datetime_info
                
            except json.JSONDecodeError:
                logger.error(f"Failed to parse datetime response: {response}")
                return {
                    "is_specific_date": False,
                    "is_specific_time": False,
                    "start_date": "",
                    "end_date": "",
                    "start_time": "",
                    "end_time": "",
                    "day_context": "",
                    "time_context": "",
                    "confidence": 0.1
                }
                
        except Exception as e:
            logger.error(f"Error extracting datetime info: {e}")
            return {
                "is_specific_date": False,
                "is_specific_time": False,
                "start_date": "",
                "end_date": "",
                "start_time": "",
                "end_time": "",
                "day_context": "",
                "time_context": "",
                "confidence": 0.1
            } 