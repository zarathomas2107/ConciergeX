import pandas as pd
import json

# Read the CSV file
df = pd.read_csv('LLM_Finetuning___Bookings.csv')
print(f"Total rows in original data: {len(df)}")

# Print sample of raw data
print("\nSample of raw data:")
print(df[['request', 'response']].head(1))

# Function to extract request content - simplified
def extract_request_content(request_str):
    try:
        request_dict = json.loads(request_str)
        messages = request_dict.get('messages', [])
        user_messages = [m['content'] for m in messages if m['role'] == 'user']
        return user_messages[-1].strip('"') if user_messages else None
    except Exception as e:
        print(f"Request error: {e}")
        return None

# Function to extract JSON from response - simplified
def extract_response_content(response_str):
    try:
        # Parse response JSON
        response_dict = json.loads(response_str)
        print(f"\nResponse keys: {response_dict.keys()}")
        
        # Get the choices
        choices = response_dict.get('choices', [])
        if choices:
            print(f"Found choices: {len(choices)}")
            message = choices[0].get('message', {})
            print(f"Message content: {message.get('content', '')[:100]}...")
            return message.get('content')
        return None
    except Exception as e:
        print(f"Response error: {e}")
        return None

# Create new columns
df['extracted_request'] = df['request'].apply(extract_request_content)
print(f"\nRequests extracted: {df['extracted_request'].notna().sum()}")

df['extracted_response'] = df['response'].apply(extract_response_content)
print(f"Responses extracted: {df['extracted_response'].notna().sum()}")

# Keep only the columns we need and drop nulls
result_df = df[['extracted_request', 'extracted_response']].dropna()
print(f"\nFinal rows after dropping nulls: {len(result_df)}")

# Print first few rows before saving
print("\nFirst few rows of result_df:")
print(result_df.head())

# Save to CSV
result_df.to_csv('extracted_data.csv', index=False)
print("\nData saved to extracted_data.csv")
