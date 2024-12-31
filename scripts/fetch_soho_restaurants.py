from config import CONFIG

import pandas as pd
import googlemaps
from datetime import datetime
import time
import os

def fetch_soho_restaurants(google_api_key):
    """
    Fetch restaurants in Soho using Google Places API and format like Restaurants_Enriched.csv
    """
    
    # Initialize Google Maps client
    gmaps = googlemaps.Client(key=google_api_key)
    
    # Soho approximate boundaries
    SOHO_CENTER = (51.5133, -0.1359)
    SEARCH_RADIUS = 800  # meters, covers most of Soho
    
    restaurant_results = []
    page_token = None
    
    print("\nSearching for restaurants in Soho...")
    
    while True:
        try:
            # Search for restaurants
            places_result = gmaps.places_nearby(
                location=SOHO_CENTER,
                radius=SEARCH_RADIUS,
                type='restaurant',
                page_token=page_token
            )
            
            # Process each restaurant
            for place in places_result.get('results', []):
                try:
                    # Get detailed information
                    details = gmaps.place(
                        place['place_id'],
                        fields=['name', 'place_id', 'formatted_address', 'rating',
                               'user_ratings_total', 'price_level', 'geometry',
                               'business_status']
                    )['result']
                    
                    # Format data to match Restaurants_Enriched.csv structure
                    restaurant_data = {
                        'RestaurantID': details.get('place_id', ''),
                        'Name': details.get('name', ''),
                        'CuisineType': None,  # Left as None as requested
                        'Country': 'UK',
                        'City': 'London',
                        'Address': details.get('formatted_address', ''),
                        'Rating': details.get('rating', ''),
                        'BusinessStatus': details.get('business_status', ''),
                        'Latitude': details['geometry']['location'].get('lat', ''),
                        'Longitude': details['geometry']['location'].get('lng', ''),
                        'PriceLevel': details.get('price_level', '')
                    }
                    
                    restaurant_results.append(restaurant_data)
                    print(f"✓ Added: {restaurant_data['Name']}")
                    
                    # Sleep briefly to avoid hitting API limits
                    time.sleep(0.2)
                    
                except Exception as e:
                    print(f"✗ Error processing restaurant: {str(e)}")
                    continue
            
            # Check if there are more results
            page_token = places_result.get('next_page_token')
            if not page_token:
                break
                
            # Wait before making the next request (required for next_page_token to become valid)
            time.sleep(2)
            
        except Exception as e:
            print(f"✗ Error fetching places: {str(e)}")
            break
    
    if not restaurant_results:
        print("\nNo restaurants found!")
        return pd.DataFrame()
    
    # Convert to DataFrame
    print("\nCreating results DataFrame...")
    results_df = pd.DataFrame(restaurant_results)
    
    # Ensure all columns match Restaurants_Enriched.csv
    expected_columns = [
        'RestaurantID', 'Name', 'CuisineType', 'Country', 'City', 
        'Address', 'Rating', 'BusinessStatus', 'Latitude', 'Longitude', 'PriceLevel'
    ]
    
    for col in expected_columns:
        if col not in results_df.columns:
            results_df[col] = None
    
    # Reorder columns to match original CSV
    results_df = results_df[expected_columns]
    
    # Save results
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'soho_restaurants_{timestamp}.csv'
    results_df.to_csv(filename, index=False)
    print(f"\n✓ Saved {len(results_df)} restaurants to {filename}")
    
    return results_df

if __name__ == "__main__":
    # Your Google API key
    GOOGLE_API_KEY = "AIzaSyDVq2F546uy7O72qnC6F4lA22uG3nwuvB8"
    
    # Fetch restaurants
    restaurants_df = fetch_soho_restaurants(GOOGLE_API_KEY)
    
    # Print summary
    if not restaurants_df.empty:
        print("\nRestaurants Summary:")
        print(f"Total restaurants found: {len(restaurants_df)}")
        print("\nSample of restaurants:")
        print(restaurants_df[['Name', 'Address', 'Rating', 'PriceLevel']].head()) 