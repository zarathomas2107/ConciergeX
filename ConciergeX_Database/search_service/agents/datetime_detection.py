import ollama
from datetime import datetime, timedelta
from typing import Dict
import json

class DateTimeAgent:
    def __init__(self):
        """Initialize the DateTimeAgent with necessary configurations"""
        self.client = ollama.Client()
        
        # Define standard meal times and durations
        self.MEAL_TIMES = {
            'breakfast': {'start': '07:00', 'end': '10:00'},  # 3 hours
            'brunch': {'start': '10:30', 'end': '13:00'},    # 2.5 hours
            'lunch': {'start': '12:00', 'end': '14:00'},     # 2 hours
            'dinner': {'start': '19:00', 'end': '21:00'},    # 2 hours
            'meeting': {'duration': 2}  # hours
        }
        
        # Initialize available functions
        self.available_functions = {
            'get_current_time': self.get_current_time,
            'get_next_weekend': self.get_next_weekend,
            'get_this_weekend': self.get_this_weekend,
            'get_tonight': self.get_tonight,
            'get_next_week': self.get_next_week,
            'get_tomorrow': self.get_tomorrow,
            'get_specific_day': self.get_specific_day,
            'get_month_range': self.get_month_range,
        }
        
        # Initialize system prompt
        self.system_prompt = """
You are a datetime extraction specialist. Your task is to extract and calculate date and time information from user queries.

Format your response as a valid JSON object with these REQUIRED fields:
{
    "start_date": "YYYY-MM-DD",  // REQUIRED: Must be filled from appropriate tool
    "end_date": "YYYY-MM-DD",    // REQUIRED: Must be filled from appropriate tool
    "start_time": "HH:MM",       // REQUIRED: Use empty string if not specified
    "end_time": "HH:MM",         // REQUIRED: Use empty string if not specified
    "day_context": "string",     // REQUIRED: today/tonight/tomorrow/next week/this weekend/next weekend/this month/monday/tuesday/etc.
    "time_context": "string"     // REQUIRED: breakfast/lunch/dinner/brunch/meeting/empty string
}  

IMPORTANT RULES:
1. ALL fields must be included in the response
2. start_date and end_date must ALWAYS be filled using values from tool responses
3. For time ranges, use EXACTLY these standard durations:
   - For breakfast: start="07:00", end="10:00" (3 hours)
   - For brunch: start="10:30", end="13:00" (2.5 hours)
   - For lunch: start="12:00", end="14:00" (2 hours)
   - For dinner: start="19:00", end="21:00" (2 hours)
   - For meetings: use 2 hour duration (e.g., if start is "15:00", end must be "17:00")
4. For date ranges:
   - Always include both start_date and end_date from tool responses
   - For "today" or "tonight": Use get_tonight() tool
   - For "tomorrow": Use get_tomorrow() tool
   - For "this weekend": Use get_this_weekend() tool
   - For "next weekend": Use get_next_weekend() tool
   - For "next week": Use get_next_week() tool
   - For specific days (e.g., "Thursday"): Use get_specific_day() tool
   - For months (e.g., "March"): Use get_month_range() tool

AVAILABLE TOOLS:
1. get_current_time: Returns Unix timestamp (seconds since epoch)
2. get_next_weekend: Returns dictionary with next weekend's dates
3. get_this_weekend: Returns dictionary with this weekend's dates
4. get_tonight: Returns dictionary with tonight's date
5. get_tomorrow: Returns dictionary with tomorrow's date
6. get_next_week: Returns dictionary with next week's dates
7. get_specific_day: Returns dictionary with date for a specific day
8. get_month_range: Returns dictionary with start and end dates for a month:
   {
       "start_date": "YYYY-MM-DD",  // First day of the month
       "end_date": "YYYY-MM-DD"     // Last day of the month
   }

EXAMPLE RESPONSES:
1. Query: "Breakfast on Thursday"
Tool call: get_specific_day("thursday") returns {"start_date": "2024-03-21", "end_date": "2024-03-21"}
Response:
{
    "start_date": "2024-03-21",  // From get_specific_day tool
    "end_date": "2024-03-21",    // From get_specific_day tool
    "start_time": "07:00",
    "end_time": "10:00",         // 3 hour standard breakfast duration
    "day_context": "thursday",
    "time_context": "breakfast"
}

2. Query: "Dinner in March"
Tool call: get_month_range("march") returns {"start_date": "2024-03-01", "end_date": "2024-03-31"}
Response:
{
    "start_date": "2024-03-01",  // From get_month_range tool
    "end_date": "2024-03-31",    // From get_month_range tool
    "start_time": "19:00",
    "end_time": "21:00",         // 2 hour standard dinner duration
    "day_context": "march",
    "time_context": "dinner"
}

IMPORTANT: Return ONLY the JSON object, no comments or explanations. ALWAYS use exact dates from tool responses and EXACT durations from the rules above.
"""
        
        # Initialize messages
        self.messages = [
            {'role': 'system', 'content': self.system_prompt}
        ]

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

    def get_next_week(self) -> Dict[str, str]:
        """Returns dictionary with next week's dates (Monday to Sunday)"""
        today = datetime.now()
        # Calculate days until next Monday
        days_until_monday = (0 - today.weekday()) % 7
        if days_until_monday == 0:  # If today is Monday
            days_until_monday = 7  # Go to next Monday
        
        next_monday = today + timedelta(days=days_until_monday)
        next_sunday = next_monday + timedelta(days=6)  # Sunday is 6 days after Monday
        
        return {
            'start_date': next_monday.strftime('%Y-%m-%d'),
            'end_date': next_sunday.strftime('%Y-%m-%d')
        }

    def get_tomorrow(self) -> Dict[str, str]:
        """Returns dictionary with tomorrow's date"""
        tomorrow = datetime.now() + timedelta(days=1)
        return {
            'start_date': tomorrow.strftime('%Y-%m-%d'),
            'end_date': tomorrow.strftime('%Y-%m-%d')
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
        return {
            'start_date': target_date.strftime('%Y-%m-%d'),
            'end_date': target_date.strftime('%Y-%m-%d')
        }

    def get_month_range(self, month_name: str = None) -> Dict[str, str]:
        """Returns dictionary with start and end dates for a month"""
        # Map month names to numbers (1-12)
        month_map = {
            'january': 1, 'jan': 1,
            'february': 2, 'feb': 2,
            'march': 3, 'mar': 3,
            'april': 4, 'apr': 4,
            'may': 5,
            'june': 6, 'jun': 6,
            'july': 7, 'jul': 7,
            'august': 8, 'aug': 8,
            'september': 9, 'sep': 9,
            'october': 10, 'oct': 10,
            'november': 11, 'nov': 11,
            'december': 12, 'dec': 12
        }

        today = datetime.now()
        
        if not month_name:
            # Use current month if no month specified
            target_month = today.month
            target_year = today.year
        else:
            # Clean up month name and handle potential JSON string
            if isinstance(month_name, str):
                try:
                    # Try to parse as JSON in case it's a JSON string
                    parsed = json.loads(month_name)
                    if isinstance(parsed, dict) and 'month_name' in parsed:
                        month_name = parsed['month_name']
                except json.JSONDecodeError:
                    pass
            
            # Get month number from name
            month_name = str(month_name).lower().strip()
            target_month = month_map.get(month_name)
            
            if target_month is None:
                # Invalid month name, use current month
                target_month = today.month
                target_year = today.year
            else:
                target_year = today.year
                # If the target month is earlier than current month, use next year
                if target_month < today.month:
                    target_year += 1

        # Calculate first day of month
        start_date = datetime(target_year, target_month, 1)
        
        # Calculate last day of month
        if target_month == 12:
            end_date = datetime(target_year + 1, 1, 1) - timedelta(days=1)
        else:
            end_date = datetime(target_year, target_month + 1, 1) - timedelta(days=1)

        return {
            'start_date': start_date.strftime('%Y-%m-%d'),
            'end_date': end_date.strftime('%Y-%m-%d')
        }

    def enforce_meal_times(self, response_str: str) -> str:
        """Enforces the standard meal times from MEAL_TIMES constant"""
        try:
            response = json.loads(response_str)
            time_context = response.get('time_context', '').lower()
            
            if time_context in self.MEAL_TIMES:
                if time_context == 'meeting':
                    # Handle meetings (2 hour duration)
                    if response.get('start_time'):
                        start_hour = int(response['start_time'].split(':')[0])
                        end_hour = start_hour + self.MEAL_TIMES['meeting']['duration']
                        response['end_time'] = f"{end_hour:02d}:00"
                else:
                    # Handle meals
                    # If a specific start time is given, adjust end time to maintain duration
                    if response.get('start_time'):
                        start_hour = int(response['start_time'].split(':')[0])
                        standard_duration = (
                            int(self.MEAL_TIMES[time_context]['end'].split(':')[0]) - 
                            int(self.MEAL_TIMES[time_context]['start'].split(':')[0])
                        )
                        end_hour = start_hour + standard_duration
                        response['end_time'] = f"{end_hour:02d}:00"
                    else:
                        # Use standard times if no specific time given
                        response['start_time'] = self.MEAL_TIMES[time_context]['start']
                        response['end_time'] = self.MEAL_TIMES[time_context]['end']
            
            return json.dumps(response, indent=4)
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            print(f"Error enforcing meal times: {str(e)}")
            return response_str

    def process_query(self, query: str) -> Dict:
        """Process a single query and return the datetime information"""
        # Reset messages except system prompt
        self.messages[1:] = [{'role': 'user', 'content': query}]

        # Ask Ollama to handle the query
        response = self.client.chat(
            'llama3.1',
            messages=self.messages,
            tools=[
                {
                    'type': 'function',
                    'function': {
                        'name': 'get_current_time',
                        'description': 'Returns current Unix timestamp (seconds since epoch) as an integer.',
                        'parameters': {
                            'type': 'object',
                            'properties': {},
                            'required': []
                        }
                    },
                },
                {
                    'type': 'function',
                    'function': {
                        'name': 'get_next_weekend',
                        'description': 'Returns dictionary with next weekend dates (Saturday and Sunday).',
                        'parameters': {
                            'type': 'object',
                            'properties': {},
                            'required': []
                        }
                    },
                },
                {
                    'type': 'function',
                    'function': {
                        'name': 'get_this_weekend',
                        'description': 'Returns dictionary with this weekend dates (Saturday and Sunday).',
                        'parameters': {
                            'type': 'object',
                            'properties': {},
                            'required': []
                        }
                    },
                },
                {
                    'type': 'function',
                    'function': {
                        'name': 'get_tonight',
                        'description': 'Returns dictionary with tonight\'s date.',
                        'parameters': {
                            'type': 'object',
                            'properties': {},
                            'required': []
                        }
                    },
                },
                {
                    'type': 'function',
                    'function': {
                        'name': 'get_tomorrow',
                        'description': 'Returns dictionary with tomorrow\'s date.',
                        'parameters': {
                            'type': 'object',
                            'properties': {},
                            'required': []
                        }
                    },
                },
                {
                    'type': 'function',
                    'function': {
                        'name': 'get_next_week',
                        'description': 'Returns dictionary with next week\'s dates (Monday to Sunday).',
                        'parameters': {
                            'type': 'object',
                            'properties': {},
                            'required': []
                        }
                    },
                },
                {
                    'type': 'function',
                    'function': {
                        'name': 'get_specific_day',
                        'description': 'Returns dictionary with date for a specific day.',
                        'parameters': {
                            'type': 'object',
                            'properties': {
                                'day_name': {
                                    'type': 'string',
                                    'description': 'The name of the day (e.g., "Monday", "Tuesday").'
                                }
                            },
                            'required': ['day_name']
                        }
                    },
                },
                {
                    'type': 'function',
                    'function': {
                        'name': 'get_month_range',
                        'description': 'Returns dictionary with start and end dates for a month.',
                        'parameters': {
                            'type': 'object',
                            'properties': {
                                'month_name': {
                                    'type': 'string',
                                    'description': 'The name of the month (e.g., "March", "April").'
                                }
                            },
                            'required': ['month_name']
                        }
                    },
                }
            ],
        )

        result = {}
        if response.message.tool_calls:
            tool_outputs = []
            for tool in response.message.tool_calls:
                function_name = tool.function.name
                function_to_call = self.available_functions.get(function_name)
                
                if function_to_call:
                    try:
                        # Parse arguments if they exist
                        args = {}
                        if hasattr(tool.function, 'arguments') and tool.function.arguments:
                            try:
                                # Parse arguments from string or dict
                                if isinstance(tool.function.arguments, str):
                                    parsed_args = json.loads(tool.function.arguments)
                                else:
                                    parsed_args = tool.function.arguments
                                
                                # Handle functions that require arguments
                                if function_name == 'get_specific_day' and 'day_name' in parsed_args:
                                    args = {'day_name': parsed_args['day_name']}
                                elif function_name == 'get_month_range' and 'month_name' in parsed_args:
                                    args = {'month_name': parsed_args['month_name']}
                                
                            except json.JSONDecodeError as e:
                                print(f"Error parsing arguments for {function_name}: {str(e)}")
                        
                        # Call function with or without arguments
                        output = function_to_call(**args) if args else function_to_call()
                        tool_outputs.append({
                            'output': output,
                            'name': function_name
                        })
                    except Exception as e:
                        print(f'Error calling {function_name}: {str(e)}')
                        continue

            # Add tool outputs to messages
            self.messages.append(response.message)
            for tool_output in tool_outputs:
                self.messages.append({
                    'role': 'tool', 
                    'content': str(tool_output['output']), 
                    'name': tool_output['name']
                })

            # Final Ollama response
            final_response = self.client.chat('llama3.1', messages=self.messages)
            try:
                # Try to parse the response as JSON first
                json_response = json.loads(final_response.message.content)
                # Enforce meal times
                result = json.loads(self.enforce_meal_times(json.dumps(json_response)))
            except json.JSONDecodeError:
                result = {'error': 'Failed to parse response'}

        return result

# Example usage
if __name__ == '__main__':
    try:
        # Test the standalone function
        import sys
        if len(sys.argv) > 1:
            query = ' '.join(sys.argv[1:])
            agent = DateTimeAgent()
            result = agent.process_query(query)
            print(json.dumps(result, indent=2))
        else:
            # Run the test suite if no query provided
            agent = DateTimeAgent()
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
                "Dinner in March"
            ]
            for query in test_queries:
                print("\nTesting query:", query)
                result = agent.process_query(query)
                print(json.dumps(result, indent=2))
    except KeyboardInterrupt:
        print('\nGoodbye!')
