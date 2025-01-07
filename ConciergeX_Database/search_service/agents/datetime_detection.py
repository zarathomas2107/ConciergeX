import logging
from datetime import datetime, timedelta
from typing import Dict, Any
import aiohttp
import json
import asyncio
from search_service.clients.openai_client import OpenAIClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DateTimeAgent:
    """Agent for detecting and processing datetime information from queries."""
    
    def __init__(self):
        """Initialize the DateTimeAgent."""
        self.logger = logging.getLogger(__name__)
        self.openai_client = OpenAIClient()
        
        # Define standard meal times and durations
        self.MEAL_TIMES = {
            'breakfast': {'start': '07:00', 'end': '10:00'},  # 3 hours
            'brunch': {'start': '10:30', 'end': '13:00'},    # 2.5 hours
            'lunch': {'start': '12:00', 'end': '14:00'},     # 2 hours
            'dinner': {'start': '19:00', 'end': '21:00'},    # 2 hours
            'meeting': {'duration': 2}  # hours
        }
        
        # Map various time contexts to standard meal times
        self.TIME_CONTEXT_MAP = {
            'morning': 'breakfast',
            'afternoon': 'lunch',
            'evening': 'dinner',
            'night': 'dinner'
        }
        
        # System prompt for datetime extraction
        self.system_prompt = """
            You are a datetime extraction specialist. Your task is to extract date and time information from user queries.

Format your response as a valid JSON object with these REQUIRED fields:
{
    "start_date": "YYYY-MM-DD",  // REQUIRED: Must be filled from appropriate tool
    "end_date": "YYYY-MM-DD",    // REQUIRED: Must be filled from appropriate tool
    "start_time": "HH:MM",       // REQUIRED: Use empty string if not specified
    "end_time": "HH:MM",         // REQUIRED: Use empty string if not specified
    "day_context": "string",     // REQUIRED: today/tonight/tomorrow/next week/this weekend/next weekend/this month/monday/tuesday/etc.
    "time_context": "string"     // REQUIRED: breakfast/lunch/dinner/brunch/meeting/morning/afternoon/evening/empty string
}  

IMPORTANT RULES:
1. ALL fields must be included in the response
2. start_date and end_date must ALWAYS be filled
3. For time ranges, use EXACTLY these standard durations:
   - For breakfast/morning: start="07:00", end="10:00" (3 hours)
   - For brunch: start="10:30", end="13:00" (2.5 hours)
   - For lunch/afternoon: start="12:00", end="14:00" (2 hours)
   - For dinner/evening/night: start="19:00", end="21:00" (2 hours)
   - For meetings: use 2 hour duration from specified start time
4. Return ONLY the JSON object, no comments or explanations
"""

    def get_current_time(self) -> int:
        """Returns current Unix timestamp in seconds"""
        return int(datetime.now().timestamp())

    def get_next_weekend(self) -> Dict[str, str]:
        """Returns dictionary with next weekend's dates"""
        today = datetime.now()
        # Calculate days until next Saturday
        days_until_saturday = (5 - today.weekday()) % 7
        if days_until_saturday == 0 and today.hour >= 0:  # If it's already Saturday
            days_until_saturday = 7
        
        next_saturday = today + timedelta(days=days_until_saturday)
        next_sunday = next_saturday + timedelta(days=1)
        
        return {
            'start_date': next_saturday.strftime('%Y-%m-%d'),
            'end_date': next_sunday.strftime('%Y-%m-%d')
        }

    def timestamp_to_date(self, timestamp: int) -> str:
        """Convert Unix timestamp to YYYY-MM-DD format"""
        return datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d')

    def get_this_weekend(self) -> Dict[str, str]:
        """Returns dictionary with this weekend's dates"""
        today = datetime.now()
        # Calculate days until this Saturday
        days_until_saturday = (5 - today.weekday()) % 7
        if days_until_saturday == 0 and today.hour >= 0:  # If it's already Saturday
            days_until_saturday = 0
        elif days_until_saturday == 6:  # If it's Sunday
            days_until_saturday = -1
        
        this_saturday = today + timedelta(days=days_until_saturday)
        this_sunday = this_saturday + timedelta(days=1)
        
        return {
            'start_date': this_saturday.strftime('%Y-%m-%d'),
            'end_date': this_sunday.strftime('%Y-%m-%d')
        }

    def get_tonight(self) -> Dict[str, str]:
        """Returns dictionary with tonight's date"""
        today = datetime.now()
        return {
            'start_date': today.strftime('%Y-%m-%d'),
            'end_date': today.strftime('%Y-%m-%d')
        }

    def get_tomorrow(self) -> Dict[str, str]:
        """Returns dictionary with tomorrow's date"""
        tomorrow = datetime.now() + timedelta(days=1)
        return {
            'start_date': tomorrow.strftime('%Y-%m-%d'),
            'end_date': tomorrow.strftime('%Y-%m-%d')
        }

    def get_next_week(self) -> Dict[str, str]:
        """Returns dictionary with next week's dates (Monday to Sunday)"""
        today = datetime.now()
        days_until_monday = (0 - today.weekday()) % 7
        if days_until_monday == 0:  # If today is Monday
            days_until_monday = 7
            
        next_monday = today + timedelta(days=days_until_monday)
        next_sunday = next_monday + timedelta(days=6)
        
        return {
            'start_date': next_monday.strftime('%Y-%m-%d'),
            'end_date': next_sunday.strftime('%Y-%m-%d')
        }

    def get_specific_day(self, day_name: str = None) -> Dict[str, str]:
        """Returns dictionary with date for a specific day of the week"""
        if not day_name:
            return self.get_tonight()  # Default to today

        # Map day names to numbers (0 = Monday, 6 = Sunday)
        day_map = {
            'monday': 0, 'mon': 0,
            'tuesday': 1, 'tue': 1,
            'wednesday': 2, 'wed': 2,
            'thursday': 3, 'thu': 3,
            'friday': 4, 'fri': 4,
            'saturday': 5, 'sat': 5,
            'sunday': 6, 'sun': 6
        }

        today = datetime.now()
        current_weekday = today.weekday()
        target_weekday = day_map.get(day_name.lower())

        if target_weekday is None:
            return self.get_tonight()  # Invalid day name, return today

        # Calculate days until target day
        days_ahead = target_weekday - current_weekday
        
        # If the day has already passed this week, go to next week
        if days_ahead <= 0:
            days_ahead += 7

        target_date = today + timedelta(days=days_ahead)
        target_date_str = target_date.strftime('%Y-%m-%d')
        
        return {
            'start_date': target_date_str,
            'end_date': target_date_str
        }

    def enforce_meal_times(self, datetime_info: Dict) -> Dict:
        """Enforces the standard meal times from MEAL_TIMES constant"""
        try:
            time_context = datetime_info.get('time_context', '').lower()
            
            # Map general time contexts to meal times
            if time_context in self.TIME_CONTEXT_MAP:
                time_context = self.TIME_CONTEXT_MAP[time_context]
                datetime_info['time_context'] = time_context
            
            if time_context in self.MEAL_TIMES:
                if time_context == 'meeting':
                    # Handle meetings (2 hour duration)
                    if datetime_info.get('start_time'):
                        start_hour = int(datetime_info['start_time'].split(':')[0])
                        end_hour = start_hour + self.MEAL_TIMES['meeting']['duration']
                        datetime_info['end_time'] = f"{end_hour:02d}:00"
                else:
                    # Handle meals
                    # If a specific start time is given, adjust end time to maintain duration
                    if datetime_info.get('start_time'):
                        start_hour = int(datetime_info['start_time'].split(':')[0])
                        standard_duration = (
                            int(self.MEAL_TIMES[time_context]['end'].split(':')[0]) - 
                            int(self.MEAL_TIMES[time_context]['start'].split(':')[0])
                        )
                        end_hour = start_hour + standard_duration
                        datetime_info['end_time'] = f"{end_hour:02d}:00"
                    else:
                        # Use standard times if no specific time given
                        datetime_info['start_time'] = self.MEAL_TIMES[time_context]['start']
                        datetime_info['end_time'] = self.MEAL_TIMES[time_context]['end']
            
            return datetime_info
        except Exception as e:
            self.logger.error(f"Error enforcing meal times: {str(e)}")
            return datetime_info

    def get_month_dates(self, month_name: str) -> Dict[str, str]:
        """Returns dictionary with start and end dates for a given month."""
        current_date = datetime.now()
        month_map = {
            'january': 1, 'february': 2, 'march': 3, 'april': 4,
            'may': 5, 'june': 6, 'july': 7, 'august': 8,
            'september': 9, 'october': 10, 'november': 11, 'december': 12
        }
        
        target_month = month_map[month_name.lower()]
        target_year = current_date.year
        
        # If the target month is earlier than current month, use next year
        if target_month < current_date.month:
            target_year += 1
            
        # Get the last day of the month
        if target_month == 12:
            next_month = datetime(target_year + 1, 1, 1)
        else:
            next_month = datetime(target_year, target_month + 1, 1)
        last_day = (next_month - timedelta(days=1)).day
        
        return {
            'start_date': datetime(target_year, target_month, 1).strftime('%Y-%m-%d'),
            'end_date': datetime(target_year, target_month, last_day).strftime('%Y-%m-%d')
        }

    async def process_query(self, query: str) -> Dict[str, Any]:
        """Process a query to extract datetime information."""
        try:
            response = await self.openai_client.get_completion(
                prompt=query,
                system_prompt=self.system_prompt
            )
            
            if not response:
                logger.error("No response from OpenAI")
                return self._get_empty_response()
                
            # Get the day context
            day_context = response.get("day_context", "").lower()
            
            # Fill in dates based on context
            dates = {}
            if "next weekend" in day_context:
                dates = self.get_next_weekend()
            elif "this weekend" in day_context:
                dates = self.get_this_weekend()
            elif "tonight" in day_context:
                dates = self.get_tonight()
            elif "tomorrow" in day_context:
                dates = self.get_tomorrow()
            elif "next week" in day_context:
                dates = self.get_next_week()
            elif any(day in day_context.lower() for day in ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]):
                # Extract the day name from context
                for day in ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]:
                    if day in day_context.lower():
                        dates = self.get_specific_day(day)
                        break
            elif "this month" in day_context:
                # Check if a specific month is mentioned in the query
                months = ["january", "february", "march", "april", "may", "june", 
                         "july", "august", "september", "october", "november", "december"]
                for month in months:
                    if month in query.lower():
                        dates = self.get_month_dates(month)
                        break
            
            # Create response with dates
            response = {
                "start_date": dates.get("start_date", response.get("start_date", "")),
                "end_date": dates.get("end_date", response.get("end_date", "")),
                "start_time": response.get("start_time", ""),
                "end_time": response.get("end_time", ""),
                "day_context": response.get("day_context", ""),
                "time_context": response.get("time_context", "")
            }
            
            # Enforce meal times
            return self.enforce_meal_times(response)
            
        except Exception as e:
            logger.error(f"Error processing datetime query: {e}")
            return self._get_empty_response()

    def _get_empty_response(self) -> Dict[str, str]:
        """Return an empty datetime response with all fields."""
        return {
            "start_date": "",
            "end_date": "",
            "start_time": "",
            "end_time": "",
            "day_context": "",
            "time_context": ""
        }

# Example usage
if __name__ == '__main__':
    async def test_queries():
        try:
            # Test the standalone function
            import sys
            agent = DateTimeAgent()
            
            if len(sys.argv) > 1:
                query = ' '.join(sys.argv[1:])
                result = await agent.process_query(query)
                print(json.dumps(result, indent=2))
            else:
                # Run the test suite if no query provided
                test_queries = [
                    "What date is next weekend?",
                    "Dinner tonight at 7pm",
                    "Lunch tomorrow at 1pm",
                    "Breakfast on Saturday at 9am",
                    "Breakfast on Thursday",
                    "Meeting next week at 3pm",
                    "Brunch this weekend at 11am",
                    "Dinner with friends tonight",
                    "Coffee tomorrow morning at 10:30",
                    "Dinner in March",
                    "Italian restaurant near Soho with @family in February"
                ]
                for query in test_queries:
                    print("\nTesting query:", query)
                    result = await agent.process_query(query)
                    print(json.dumps(result, indent=2))
        except KeyboardInterrupt:
            print('\nGoodbye!')
            
    # Run the async test function
    asyncio.run(test_queries())
