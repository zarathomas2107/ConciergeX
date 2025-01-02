from typing import Dict, Any
from openai import AsyncOpenAI
import os
import json
import asyncio
import logging
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DateTimeAgent:
    def __init__(self):
        self.client = AsyncOpenAI(
            api_key=os.getenv("OPENAI_API_KEY")
        )
        self.max_future_months = 6

    def _validate_date_range(self, start_date: str, end_date: str) -> tuple[str, str]:
        """
        Validate and normalize date range to ensure:
        1. Dates are within the next 6 months
        2. End date is not before start date
        3. Dates are in correct format
        """
        try:
            start = datetime.strptime(start_date, "%Y-%m-%d")
            end = datetime.strptime(end_date, "%Y-%m-%d")
            
            # Get current date and max future date
            current_date = datetime.now()
            max_future_date = current_date + timedelta(days=self.max_future_months * 30)
            
            # Adjust dates if needed
            if start < current_date:
                start = current_date
            if end < start:
                end = start
            if end > max_future_date:
                end = max_future_date
            if start > max_future_date:
                start = max_future_date
                end = max_future_date
                
            return start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d")
        except ValueError as e:
            logger.error(f"Date validation error: {e}")
            return None, None

    def _validate_time_range(self, start_time: str, end_time: str) -> tuple[str, str]:
        """
        Validate and normalize time range to ensure:
        1. Times are in 24-hour format with seconds (HH:MM:SS)
        2. End time is not before start time
        3. Times are in correct format
        """
        try:
            # Add ":00" seconds if not provided
            if len(start_time) == 5:
                start_time += ":00"
            if len(end_time) == 5:
                end_time += ":00"
                
            start = datetime.strptime(start_time, "%H:%M:%S")
            end = datetime.strptime(end_time, "%H:%M:%S")
            
            # If end time is before start time, assume it's for the next day
            if end < start:
                end = start
                
            return start.strftime("%H:%M:%S"), end.strftime("%H:%M:%S")
        except ValueError as e:
            logger.error(f"Time validation error: {e}")
            return None, None

    async def extract_datetime(self, query: str) -> dict:
        """
        Extract date and time information from a user query.
        """
        logger.info(f"Processing datetime query: {query}")
        
        try:
            completion = await self.client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {
                        "role": "system",
                        "content": """You are a datetime extraction specialist. Extract date and time information from user queries.

                        Format your response as a valid JSON object with these fields:
                        {
                            "start_date": "YYYY-MM-DD",
                            "end_date": "YYYY-MM-DD",
                            "start_time": "HH:MM:SS (24-hour format with seconds)",
                            "end_time": "HH:MM:SS (24-hour format with seconds)",
                            "confidence": number between 0 and 1,
                            "is_specific_date": boolean,
                            "is_specific_time": boolean,
                            "date_context": "string describing date context",
                            "time_context": "string describing time context"
                        }

                        Examples:
                        1. "Show me showtimes for January" ->
                        {
                            "start_date": "2025-01-01",
                            "end_date": "2025-01-31",
                            "start_time": "",
                            "end_time": "",
                            "confidence": 0.9,
                            "is_specific_date": false,
                            "is_specific_time": false,
                            "date_context": "January 2025",
                            "time_context": ""
                        }

                        2. "Book for January 15th at 7:30 PM" ->
                        {
                            "start_date": "2025-01-15",
                            "end_date": "2025-01-15",
                            "start_time": "19:30:00",
                            "end_time": "19:30:00",
                            "confidence": 0.95,
                            "is_specific_date": true,
                            "is_specific_time": true,
                            "date_context": "January 15th, 2025",
                            "time_context": "Evening showing"
                        }

                        Always use the next occurrence of dates (e.g., if it's December 2024 and someone asks for January, use January 2025).
                        For times, use 24-hour format with seconds (e.g., "7:30 PM" should be "19:30:00").
                        If no date/time is mentioned, leave those fields empty strings.
                        """
                    },
                    {
                        "role": "user",
                        "content": query
                    }
                ]
            )

            result = json.loads(completion.choices[0].message.content)
            logger.info(f"GPT-4 extraction result: {result}")

            # Validate date range
            if result['start_date'] and result['end_date']:
                start_date, end_date = self._validate_date_range(
                    result['start_date'], 
                    result['end_date']
                )
                result['start_date'] = start_date
                result['end_date'] = end_date

            # Validate time range
            if result['start_time'] and result['end_time']:
                start_time, end_time = self._validate_time_range(
                    result['start_time'], 
                    result['end_time']
                )
                result['start_time'] = start_time
                result['end_time'] = end_time

            return result

        except Exception as e:
            logger.error(f"Error in datetime extraction: {e}")
            return {
                "start_date": "",
                "end_date": "",
                "start_time": "",
                "end_time": "",
                "confidence": 0,
                "is_specific_date": False,
                "is_specific_time": False,
                "date_context": "",
                "time_context": ""
            } 