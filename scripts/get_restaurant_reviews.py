import os
from dotenv import load_dotenv
import requests
from supabase import create_client
import time
from datetime import datetime

# Load environment variables
load_dotenv()

# Check for required environment variables
required_vars = ['GOOGLE_API_KEY', 'SUPABASE_URL', 'SUPABASE_KEY']
missing_vars = [var for var in required_vars if not os.getenv(var)]
if missing_vars:
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

# Initialize Supabase client
supabase = create_client(
    os.getenv('SUPABASE_URL'),
    os.getenv('SUPABASE_KEY')
)

def create_reviews_table():
    """Create the restaurants_reviews table if it doesn't exist"""
    try:
        # First create the function to execute SQL if it doesn't exist
        create_function_sql = """
        create or replace function exec_sql(sql_query text)
        returns void
        language plpgsql
        security definer
        as $$
        begin
            execute sql_query;
        end;
        $$;
        """
        
        # Create the function first
        supabase.rpc('exec_sql', {'sql_query': create_function_sql}).execute()
        
        # Then create the table
        table_sql = """
        create table if not exists restaurants_reviews (
            id uuid default uuid_generate_v4() primary key,
            restaurant_id text references restaurants("RestaurantID"),
            author_name text,
            rating integer,
            text text,
            time timestamp with time zone,
            relative_time_description text,
            created_at timestamp with time zone default now()
        );

        create index if not exists idx_restaurant_reviews_restaurant_id 
            on restaurants_reviews(restaurant_id);
        """
        
        supabase.rpc('exec_sql', {'sql_query': table_sql}).execute()
        print("Reviews table created successfully")
    except Exception as e:
        print(f"Error creating table: {str(e)}")
        raise

def clear_reviews_table():
    """Clear all reviews from the table"""
    try:
        sql = "delete from restaurants_reviews where true"
        supabase.rpc('exec_sql', {'sql_query': sql}).execute()
        print("Cleared existing reviews")
    except Exception as e:
        print(f"Error clearing reviews: {str(e)}")
        raise

def get_top_reviews(place_id: str) -> list:
    """Get top 5 reviews using direct Google Places API call"""
    try:
        url = "https://maps.googleapis.com/maps/api/place/details/json"
        params = {
            'place_id': place_id,
            'fields': 'name,reviews',
            'key': os.getenv('GOOGLE_API_KEY')
        }
        
        response = requests.get(url, params=params)
        data = response.json()
        
        if 'result' not in data:
            print(f"No results found for place_id: {place_id}")
            return []
        
        restaurant_name = data['result'].get('name', 'Unknown')
        reviews = data['result'].get('reviews', [])
        
        # Sort reviews by rating (descending) and take top 5
        reviews.sort(key=lambda x: x.get('rating', 0), reverse=True)
        top_reviews = reviews[:5]
        
        print(f"Found {len(top_reviews)} reviews for {restaurant_name}")
        
        # Format reviews for database
        formatted_reviews = []
        for review in top_reviews:
            formatted_reviews.append({
                'restaurant_id': place_id,
                'author_name': review.get('author_name'),
                'rating': review.get('rating'),
                'text': review.get('text'),
                'time': datetime.fromtimestamp(review.get('time')).isoformat(),
                'relative_time_description': review.get('relative_time_description'),
            })
        
        return formatted_reviews
    
    except Exception as e:
        print(f"Error fetching reviews for place_id {place_id}: {str(e)}")
        return []

def main():
    try:
        # Create reviews table
        create_reviews_table()
        
        # Clear existing reviews
        clear_reviews_table()
        
        # Get all restaurant place_ids
        response = supabase.from_('restaurants').select('RestaurantID').execute()
        restaurants = response.data
        
        if not restaurants:
            print("No restaurants found in database")
            return
        
        print(f"Found {len(restaurants)} restaurants to process")
        total_reviews = 0
        
        # Process each restaurant
        for i, restaurant in enumerate(restaurants, 1):
            place_id = restaurant['RestaurantID']
            print(f"\nProcessing restaurant {i}/{len(restaurants)} with place_id: {place_id}")
            
            # Get top reviews for the restaurant
            reviews = get_top_reviews(place_id)
            
            if reviews:
                try:
                    # Insert reviews into database
                    result = supabase.from_('restaurants_reviews').insert(reviews).execute()
                    total_reviews += len(reviews)
                    print(f"Successfully inserted {len(reviews)} reviews")
                except Exception as e:
                    print(f"Error inserting reviews: {str(e)}")
            
            # Respect Google Places API rate limits
            time.sleep(2)
        
        print(f"\nFinished processing all restaurants. Total reviews added: {total_reviews}")
        
    except Exception as e:
        print(f"An error occurred: {str(e)}")

if __name__ == "__main__":
    main()