import os
from dotenv import load_dotenv
import requests
from supabase import create_client
import time
from datetime import datetime
import json

# Load environment variables
load_dotenv()

# Check for required environment variables
required_vars = ['OPENAI_API_KEY', 'OPENAI_MODEL_ID', 'SUPABASE_URL', 'SUPABASE_KEY']
missing_vars = [var for var in required_vars if not os.getenv(var)]
if missing_vars:
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

# OpenAI API configuration
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
MODEL_ID = os.getenv('OPENAI_MODEL_ID')
OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"

# Initialize Supabase client
supabase = create_client(
    os.getenv('SUPABASE_URL'),
    os.getenv('SUPABASE_KEY')
)

def get_features():
    """Get all feature columns from the restaurants_features table"""
    feature_columns = [
        'Dog_Friendly', 'Business_Meals', 'Birthdays', 'Date Nights',
        'Pre_Theatre', 'Cheap_Eat', 'Fine_Dining', 'kids', 'solo',
        'Bar', 'Casual_Dinner', 'Brunch', 'Vegetarian', 'Vegan',
        'Breakfast', 'Lunch', 'Dinner'
    ]
    return feature_columns

def get_restaurant_reviews(restaurant_id):
    """Get all reviews for a specific restaurant"""
    try:
        response = supabase.table('restaurants_reviews')\
            .select('text')\
            .eq('restaurant_id', restaurant_id)\
            .execute()
        return [review['text'] for review in response.data]
    except Exception as e:
        print(f"Error getting reviews for restaurant {restaurant_id}: {str(e)}")
        return []

def analyze_reviews(reviews, features, restaurant_name):
    """Use LLM to analyze reviews and identify features"""
    try:
        # Combine all reviews into one text
        combined_reviews = "\n".join(reviews)
        
        # Create the prompt
        prompt = f"""Based on these reviews for restaurant "{restaurant_name}", determine which of these characteristics apply:

Features to analyze:
- Dog_Friendly: allows dogs
- Business_Meals: suitable for business meetings
- Birthdays: good for birthday celebrations
- Date Nights: romantic or good for dates
- Pre_Theatre: suitable for pre-theatre dining
- Cheap_Eat: affordable dining
- Fine_Dining: upscale dining experience
- kids: child-friendly
- solo: comfortable for solo diners
- Bar: has a good bar/drinks
- Casual_Dinner: good for casual dining
- Brunch: serves brunch
- Vegetarian: good vegetarian options
- Vegan: good vegan options
- Breakfast: serves breakfast
- Lunch: serves lunch
- Dinner: serves dinner

Reviews:
{combined_reviews}

Return your response as a JSON object with feature names EXACTLY as shown above and boolean values (true/false) indicating if they apply. If unsure about a feature, set it to null.
Example: {{"Dog_Friendly": true, "Business_Meals": false, "Date Nights": true}}"""

        try:
            headers = {
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json"
            }
            
            data = {
                "model": MODEL_ID,
                "messages": [
                    {
                        "role": "system", 
                        "content": "You are a restaurant review analyzer. Return ONLY a JSON object with the exact feature names as specified."
                    },
                    {"role": "user", "content": prompt}
                ]
            }
            
            response = requests.post(OPENAI_API_URL, headers=headers, json=data)
            response.raise_for_status()
            
            result = response.json()
            if "choices" in result and len(result["choices"]) > 0:
                content = result["choices"][0]["message"]["content"]
                features_result = json.loads(content)
                
                # No need to clean the keys - keep them exactly as in the database
                print(f"Successfully analyzed reviews for {restaurant_name}")
                return features_result
            else:
                print(f"Unexpected API response format for {restaurant_name}")
                return {}
            
        except requests.exceptions.RequestException as api_error:
            print(f"OpenAI API error for {restaurant_name}: {str(api_error)}")
            if hasattr(api_error.response, 'text'):
                print(f"Response text: {api_error.response.text}")
            raise
            
        except json.JSONDecodeError as json_error:
            print(f"Error parsing JSON response for {restaurant_name}: {str(json_error)}")
            return {}
    
    except Exception as e:
        print(f"Error analyzing reviews for {restaurant_name}: {str(e)}")
        return {}

def update_restaurant_features(restaurant_id, features_analysis):
    """Update the restaurants_features table"""
    try:
        # Update the features for this restaurant
        features_analysis['RestaurantID'] = restaurant_id
        
        # Check if restaurant already exists
        existing = supabase.table('restaurants_features')\
            .select('id')\
            .eq('RestaurantID', restaurant_id)\
            .execute()
            
        if existing.data:
            # Update existing record
            supabase.table('restaurants_features')\
                .update(features_analysis)\
                .eq('RestaurantID', restaurant_id)\
                .execute()
        else:
            # Insert new record
            supabase.table('restaurants_features')\
                .insert(features_analysis)\
                .execute()
            
        print(f"Updated features for restaurant {restaurant_id}")
    
    except Exception as e:
        print(f"Error updating features for restaurant {restaurant_id}: {str(e)}")

def main():
    try:
        # Get all features
        features = get_features()
        print(f"Analyzing {len(features)} features")
        
        # Get all restaurants
        response = supabase.table('restaurants')\
            .select('RestaurantID,Name')\
            .execute()
        restaurants = response.data
        
        if not restaurants:
            raise ValueError("No restaurants found")
        
        print(f"Found {len(restaurants)} restaurants to process")
        
        # Process each restaurant
        for i, restaurant in enumerate(restaurants, 1):
            restaurant_id = restaurant['RestaurantID']
            restaurant_name = restaurant['Name']
            print(f"\nProcessing restaurant {i}/{len(restaurants)}: {restaurant_name}")
            
            # Get reviews
            reviews = get_restaurant_reviews(restaurant_id)
            if not reviews:
                print(f"No reviews found for restaurant {restaurant_id}")
                continue
            
            print(f"Found {len(reviews)} reviews")
            
            # Analyze reviews
            features_analysis = analyze_reviews(reviews, features, restaurant_name)
            if not features_analysis:
                print(f"No features identified for restaurant {restaurant_id}")
                continue
            
            # Update features in database
            update_restaurant_features(restaurant_id, features_analysis)
            
            # Respect API rate limits
            time.sleep(1)
        
        print("\nFinished processing all restaurants")
        
    except Exception as e:
        print(f"An error occurred: {str(e)}")

if __name__ == "__main__":
    main()