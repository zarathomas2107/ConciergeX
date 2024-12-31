import pandas as pd
import json

system_prompt = """
### INSTRUCTIONS:
You are an AI assistant specialized in analyzing restaurant reservation queries and generating structured JSON responses. Your task is to:
  - **Analyze User Requests:** Carefully extract intent, date, time, cuisine type, restaurant name, and number of people.
  - **Generate Structured JSON:** Always return a valid JSON object with the appropriate fields.
  - **Handle Ambiguous Queries:** If key details are missing (e.g., date, time, restaurant name), clarify by specifying missing parameters in the JSON response.
  - **Never Answer in Natural Language:** Do not attempt to answer or converse; respond only with structured JSON.

### **Response Schema:**
  ```json
  {
    "cuisine_type": "string (optional)",
    "restaurant_name": "string (optional)",
    "start_date": "YYYY-MM-DD",
    "end_date": "YYYY-MM-DD",
    "start_time": "HH:MM:SS",
    "end_time": "HH:MM:SS",
    "requested_seats": integer
  }
"""

# Read the CSV file
df = pd.read_csv('/Users/zara.thomas/PycharmProjects/NomNomNow/FlutterFlow/flutterflow/ConciergeX/PythonPrep/extended_finetuning_examples.csv')

# Create conversations
conversations = []
for idx, row in df.iterrows():
    conversation = {
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": row['Request']
            },
            {
                "role": "assistant",
                "content": row['Response']
            }
        ]
    }
    conversations.append(json.dumps(conversation))

# Join all conversations with newlines
output = "\n".join(conversations)

# Write to file
with open('formatted_conversations.jsonl', 'w') as f:
    f.write(output)

print("Sample of formatted output:")
print(conversations[0])
print("\nTotal conversations formatted:", len(conversations))
