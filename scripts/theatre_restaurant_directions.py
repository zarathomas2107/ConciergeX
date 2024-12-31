from config import CONFIG

import googlemaps
import pandas as pd
from datetime import datetime
import polyline

def find_nearby_restaurants_with_directions(theatre_lat, theatre_lng, theatre_name, restaurants_df, 
                                         google_api_key, limit=50, max_distance_km=2):
    """
    Find the nearest restaurants to a theatre location with detailed walking directions
    """
    
    # Initialize Google Maps client
    gmaps = googlemaps.Client(key=google_api_key)
    
    # Store results
    restaurant_results = []
    
    print(f"\nProcessing {len(restaurants_df)} restaurants near {theatre_name}")
    
    # Process each restaurant
    for index, restaurant in restaurants_df.iterrows():
        try:
            print(f"\nProcessing {index + 1}/{len(restaurants_df)}: {restaurant['Name']}")
            
            # Verify we have valid coordinates
            if pd.isna(restaurant['latitude']) or pd.isna(restaurant['longitude']):
                print(f"✗ Missing coordinates for {restaurant['Name']}")
                continue
                
            # Get walking directions
            directions_result = gmaps.directions(
                origin=(theatre_lat, theatre_lng),
                destination=(restaurant['latitude'], restaurant['longitude']),
                mode="walking",
                departure_time=datetime.now()
            )
            
            if directions_result:
                route = directions_result[0]
                leg = route['legs'][0]
                
                # Extract useful information
                walking_data = {
                    'restaurant_name': restaurant['Name'],
                    'address': restaurant['address'],
                    'rating': restaurant.get('rating', 'N/A'),
                    'price_level': restaurant.get('price_level', 'N/A'),
                    'website': restaurant.get('website', ''),
                    'phone': restaurant.get('phone', ''),
                    'cuisine_types': restaurant.get('types', ''),
                    'walking_distance_meters': leg['distance']['value'],
                    'walking_time_mins': round(leg['duration']['value'] / 60),
                    'route_polyline': route['overview_polyline']['points'],
                    'start_location': (theatre_lat, theatre_lng),
                    'end_location': (restaurant['latitude'], restaurant['longitude']),
                    'theatre_name': theatre_name,
                    'google_maps_url': f"https://www.google.com/maps/dir/?api=1&origin={theatre_lat},{theatre_lng}&destination={restaurant['latitude']},{restaurant['longitude']}&travelmode=walking"
                }
                
                # Add step-by-step directions
                steps = []
                for step in leg['steps']:
                    steps.append({
                        'instruction': step['html_instructions'],
                        'distance': step['distance']['text'],
                        'duration': step['duration']['text']
                    })
                walking_data['detailed_steps'] = str(steps)  # Convert to string for CSV storage
                
                restaurant_results.append(walking_data)
                print(f"✓ Added {restaurant['Name']} ({walking_data['walking_distance_meters']}m)")
                
            else:
                print(f"✗ No route found for {restaurant['Name']}")
                
        except Exception as e:
            print(f"✗ Error processing {restaurant['Name']}: {str(e)}")
            continue
    
    if not restaurant_results:
        print("\nNo restaurants were successfully processed!")
        return pd.DataFrame()  # Return empty DataFrame
    
    # Convert to DataFrame
    print("\nCreating results DataFrame...")
    results_df = pd.DataFrame(restaurant_results)
    
    # Filter by maximum distance and sort
    print(f"\nFiltering for distances <= {max_distance_km}km...")
    results_df = results_df[results_df['walking_distance_meters'] <= max_distance_km * 1000]
    
    if results_df.empty:
        print(f"No restaurants found within {max_distance_km}km!")
        return results_df
    
    results_df = results_df.sort_values('walking_distance_meters').head(limit)
    print(f"\nFound {len(results_df)} restaurants within range")
    
    # Save results
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'nearby_restaurants_with_directions_{timestamp}.csv'
    results_df.to_csv(filename, index=False)
    print(f"\n✓ Saved results to {filename}")
    
    return results_df

# Example usage:
if __name__ == "__main__":
    # Your Google API key
    GOOGLE_API_KEY = "AIzaSyDVq2F546uy7O72qnC6F4lA22uG3nwuvB8"
    
    # Load your data
    print("Loading data files...")
    theatres_df = pd.read_csv('/Users/zara.thomas/PycharmProjects/NomNomNow/FlutterFlow/flutterflow/ConciergeX/PythonPrep/soho_theatres_20241228_205224.csv')
    restaurants_df = pd.read_csv('/Users/zara.thomas/PycharmProjects/NomNomNow/FlutterFlow/flutterflow/ConciergeX/PythonPrep/Restaurants_Enriched.csv')
    
    # Print column names and data types
    print("\nRestaurant DataFrame columns:")
    print(restaurants_df.columns.tolist())
    print("\nRestaurant DataFrame info:")
    print(restaurants_df.info())
    
    # Check for any missing coordinates
    missing_rest_coords = restaurants_df[restaurants_df['Latitude'].isna() | restaurants_df['Longitude'].isna()]
    
    if not missing_rest_coords.empty:
        print("\nExample restaurants with missing coordinates:")
        print(missing_rest_coords[['Name', 'Latitude', 'Longitude']].head())
    
    # Example: Find restaurants near a specific theatre
    theatre = theatres_df.iloc[0]
    print(f"\nProcessing theatre: {theatre['name']}")
    print(f"Location: ({theatre['latitude']}, {theatre['longitude']})")
    
    # Try with explicit column names and mappings
    nearby = find_nearby_restaurants_with_directions(
        theatre_lat=float(theatre['latitude']),
        theatre_lng=float(theatre['longitude']),
        theatre_name=theatre['name'],
        restaurants_df=restaurants_df.rename(columns={
            'Name': 'Name',  # Keep original
            'Latitude': 'latitude',
            'Longitude': 'longitude',
            'Rating': 'rating',
            'PriceLevel': 'price_level',
            'Address': 'address',
            'CuisineType': 'cuisine_types'
        }),
        google_api_key=GOOGLE_API_KEY,
        limit=50,
        max_distance_km=1
    )
    
    # Print example route for the closest restaurant
    if not nearby.empty:
        closest = nearby.iloc[0]
        print(f"\nClosest restaurant: {closest['restaurant_name']}")
        print(f"Walking time: {closest['walking_time_mins']} minutes")
        print(f"Distance: {closest['walking_distance_meters']} meters")
        print(f"Google Maps: {closest['google_maps_url']}")
    else:
        print("\nNo nearby restaurants found!")