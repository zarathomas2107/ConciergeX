import pandas as pd
import json

# Read the CSV file
df = pd.read_csv('extended_finetuning_examples.csv')

# Create the JSONL format that OpenAI expects
finetune_data = []

for _, row in df.iterrows():
    # Create the training example
    example = {
        "messages": [
            {
                "role": "system",
                "content": """You are a restaurant booking assistant that processes queries and extracts structured information. 
                Return a JSON object containing: cuisine type, restaurant name, dates, times, number of seats, venue details, and relevant features."""
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
    finetune_data.append(json.dumps(example))

# Write to JSONL file
with open('restaurant_finetune.jsonl', 'w') as f:
    for item in finetune_data:
        f.write(f"{item}\n")

print(f"Created training file with {len(finetune_data)} examples") 