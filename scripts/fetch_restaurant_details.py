from config import CONFIG

import pandas as pd
import googlemaps
from datetime import datetime
import time
import json

def fetch_restaurant_details(restaurant_names, google_api_key):
    """
    Fetch all available details for specific restaurants using Google Places API
    
    Args:
        restaurant_names (list): List of restaurant names to search for
        google_api_key (str): Your Google API key
    
    Returns:
        pandas.DataFrame: DataFrame containing restaurant details
    """
    
    # Initialize Google Maps client
    gmaps = googlemaps.Client(key=google_api_key)
    
    # Request all available fields from Places API
    fields = [
        'address_component', 'adr_address', 'business_status', 
        'formatted_address', 'geometry', 'icon', 'icon_background_color',
        'icon_mask_base_uri', 'name', 'permanently_closed', 'photo',
        'place_id', 'plus_code', 'price_level', 'rating',
        'reference', 'review', 'type', 'url', 'user_ratings_total',
        'utc_offset', 'vicinity', 'website', 'wheelchair_accessible_entrance',
        'formatted_phone_number', 'international_phone_number',
        'opening_hours', 'secondary_opening_hours', 'current_opening_hours',
        'delivery', 'dine_in', 'editorial_summary', 'price_level',
        'rating', 'reservable', 'serves_beer', 'serves_breakfast',
        'serves_brunch', 'serves_dinner', 'serves_lunch', 'serves_vegetarian_food',
        'serves_wine', 'takeout', 'user_ratings_total'
    ]
    
    # Store results
    restaurant_results = []
    
    print(f"\nProcessing {len(restaurant_names)} restaurants")
    
    for index, restaurant_name in enumerate(restaurant_names, 1):
        try:
            print(f"\nProcessing {index}/{len(restaurant_names)}: {restaurant_name}")
            
            # Search for the restaurant
            places_result = gmaps.places(
                query=f"{restaurant_name} restaurant London",
                location=(51.5074, -0.1278),  # London center coordinates
                radius=10000  # 10km radius
            )
            
            if places_result['results']:
                # Get the first result
                place = places_result['results'][0]
                
                # Get detailed information
                place_details = gmaps.place(
                    place['place_id'],
                    fields=fields
                )['result']
                
                # Extract all available information
                restaurant_data = {
                    'name': place_details.get('name', ''),
                    'place_id': place['place_id'],
                    'formatted_address': place_details.get('formatted_address', ''),
                    'formatted_phone_number': place_details.get('formatted_phone_number', ''),
                    'international_phone_number': place_details.get('international_phone_number', ''),
                    'website': place_details.get('website', ''),
                    'url': place_details.get('url', ''),
                    'rating': place_details.get('rating', ''),
                    'user_ratings_total': place_details.get('user_ratings_total', ''),
                    'price_level': place_details.get('price_level', ''),
                    'business_status': place_details.get('business_status', ''),
                    'latitude': place_details['geometry']['location'].get('lat', ''),
                    'longitude': place_details['geometry']['location'].get('lng', ''),
                    'viewport_ne_lat': place_details['geometry']['viewport']['northeast'].get('lat', ''),
                    'viewport_ne_lng': place_details['geometry']['viewport']['northeast'].get('lng', ''),
                    'viewport_sw_lat': place_details['geometry']['viewport']['southwest'].get('lat', ''),
                    'viewport_sw_lng': place_details['geometry']['viewport']['southwest'].get('lng', ''),
                    'icon': place_details.get('icon', ''),
                    'icon_background_color': place_details.get('icon_background_color', ''),
                    'icon_mask_base_uri': place_details.get('icon_mask_base_uri', ''),
                    'types': ','.join(place_details.get('types', [])),
                    'wheelchair_accessible_entrance': place_details.get('wheelchair_accessible_entrance', ''),
                    'delivery': place_details.get('delivery', ''),
                    'dine_in': place_details.get('dine_in', ''),
                    'reservable': place_details.get('reservable', ''),
                    'serves_beer': place_details.get('serves_beer', ''),
                    'serves_breakfast': place_details.get('serves_breakfast', ''),
                    'serves_brunch': place_details.get('serves_brunch', ''),
                    'serves_dinner': place_details.get('serves_dinner', ''),
                    'serves_lunch': place_details.get('serves_lunch', ''),
                    'serves_vegetarian_food': place_details.get('serves_vegetarian_food', ''),
                    'serves_wine': place_details.get('serves_wine', ''),
                    'takeout': place_details.get('takeout', ''),
                }
                
                # Add opening hours if available
                if 'opening_hours' in place_details:
                    restaurant_data['weekday_hours'] = str(place_details['opening_hours'].get('weekday_text', []))
                    restaurant_data['open_now'] = place_details['opening_hours'].get('open_now', '')
                
                # Add editorial summary if available
                if 'editorial_summary' in place_details:
                    restaurant_data['editorial_summary'] = place_details['editorial_summary'].get('overview', '')
                
                # Add reviews if available
                if 'reviews' in place_details:
                    reviews = place_details['reviews']
                    restaurant_data['reviews'] = json.dumps([{
                        'author_name': review.get('author_name', ''),
                        'rating': review.get('rating', ''),
                        'relative_time_description': review.get('relative_time_description', ''),
                        'text': review.get('text', '')
                    } for review in reviews])
                
                # Add photos if available
                if 'photos' in place_details:
                    photos = place_details['photos']
                    restaurant_data['photo_references'] = json.dumps([{
                        'height': photo.get('height', ''),
                        'width': photo.get('width', ''),
                        'photo_reference': photo.get('photo_reference', '')
                    } for photo in photos])
                
                restaurant_results.append(restaurant_data)
                print(f"✓ Added {restaurant_name}")
                
            else:
                print(f"✗ No results found for {restaurant_name}")
                
            # Sleep to avoid hitting API rate limits
            time.sleep(1)
                
        except Exception as e:
            print(f"✗ Error processing {restaurant_name}: {str(e)}")
            continue
    
    if not restaurant_results:
        print("\nNo restaurants were successfully processed!")
        return pd.DataFrame()
    
    # Convert to DataFrame
    print("\nCreating results DataFrame...")
    results_df = pd.DataFrame(restaurant_results)
    
    # Save results
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'restaurant_details_{timestamp}.csv'
    results_df.to_csv(filename, index=False)
    print(f"\n✓ Saved results to {filename}")
    
    # Also save raw JSON for backup
    with open(f'restaurant_details_raw_{timestamp}.json', 'w') as f:
        json.dump(restaurant_results, f, indent=2)
    print(f"✓ Saved raw JSON to restaurant_details_raw_{timestamp}.json")
    
    return results_df

if __name__ == "__main__":
    # Your Google API key
    GOOGLE_API_KEY = "AIzaSyDVq2F546uy7O72qnC6F4lA22uG3nwuvB8"
    
    # List of restaurants you want to look up
    restaurants = [
        "Duck & Waffle London",
        "Dishoom Covent Garden",
        "The Ivy Soho",
        # Add more restaurants here
    ]
    
    # Fetch details
    restaurant_details = fetch_restaurant_details(restaurants, GOOGLE_API_KEY)
    
    # Print summary
    if not restaurant_details.empty:
        print("\nRestaurant Details Summary:")
        for _, restaurant in restaurant_details.iterrows():
            print(f"\n{restaurant['name']}:")
            print(f"Rating: {restaurant['rating']} ({restaurant['user_ratings_total']} reviews)")
            print(f"Address: {restaurant['formatted_address']}")
            print(f"Phone: {restaurant['formatted_phone_number']}")
            print(f"Website: {restaurant['website']}")
            if restaurant.get('editorial_summary'):
                print(f"Summary: {restaurant['editorial_summary']}") 