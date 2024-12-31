import pandas as pd
import googlemaps
from datetime import datetime
import polyline

def find_nearby_restaurants(theatre_lat, theatre_lng, theatre_name, restaurants_df, 
                          google_api_key, limit=50, max_distance_km=2):
    """
    Find the nearest restaurants from a provided list to a theatre location
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
            if pd.isna(restaurant['Latitude']) or pd.isna(restaurant['Longitude']):
                print(f"✗ Missing coordinates for {restaurant['Name']}")
                continue
                
            # Get walking directions
            directions_result = gmaps.directions(
                origin=(theatre_lat, theatre_lng),
                destination=(restaurant['Latitude'], restaurant['Longitude']),
                mode="walking",
                departure_time=datetime.now()
            )
            
            if directions_result:
                route = directions_result[0]
                leg = route['legs'][0]
                
                # Extract useful information
                walking_data = {
                    'restaurant_name': restaurant['Name'],
                    'cuisine_type': restaurant['CuisineType'],
                    'address': restaurant['Address'],
                    'rating': restaurant['Rating'],
                    'price_level': restaurant['PriceLevel'],
                    'walking_distance_meters': leg['distance']['value'],
                    'walking_time_mins': round(leg['duration']['value'] / 60),
                    'route_polyline': route['overview_polyline']['points'],
                    'start_location': (theatre_lat, theatre_lng),
                    'end_location': (restaurant['Latitude'], restaurant['Longitude']),
                    'theatre_name': theatre_name,
                    'google_maps_url': f"https://www.google.com/maps/dir/?api=1&origin={theatre_lat},{theatre_lng}&destination={restaurant['Latitude']},{restaurant['Longitude']}&travelmode=walking"
                }
                
                # Add step-by-step directions
                steps = []
                for step in leg['steps']:
                    steps.append({
                        'instruction': step['html_instructions'],
                        'distance': step['distance']['text'],
                        'duration': step['duration']['text']
                    })
                walking_data['detailed_steps'] = steps
                
                restaurant_results.append(walking_data)
                print(f"✓ Added {restaurant['Name']} ({walking_data['walking_distance_meters']}m)")
                
            else:
                print(f"✗ No route found for {restaurant['Name']}")
                
        except Exception as e:
            print(f"✗ Error processing {restaurant['Name']}: {str(e)}")
            continue
    
    if not restaurant_results:
        print("\nNo restaurants were successfully processed!")
        return pd.DataFrame()
    
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
    filename = f'nearby_restaurants_{theatre_name}_{timestamp}.csv'
    results_df.to_csv(filename, index=False)
    print(f"\n✓ Saved results to {filename}")
    
    return results_df

if __name__ == "__main__":
    # Your Google API key
    GOOGLE_API_KEY = "your-google-api-key"
    
    # Load your data
    print("Loading data files...")
    theatres_df = pd.read_csv('soho_theatres_20241228_205224.csv')
    restaurants_df = pd.read_csv('Restaurants_Enriched.csv')
    
    # Example: Find restaurants near a specific theatre
    theatre = theatres_df.iloc[0]  # Using first theatre as example
    print(f"\nProcessing theatre: {theatre['name']}")
    print(f"Location: ({theatre['latitude']}, {theatre['longitude']})")
    
    nearby = find_nearby_restaurants(
        theatre_lat=float(theatre['latitude']),
        theatre_lng=float(theatre['longitude']),
        theatre_name=theatre['name'],
        restaurants_df=restaurants_df,
        google_api_key=GOOGLE_API_KEY,
        limit=50,
        max_distance_km=1
    )
    
    # Print example route for the closest restaurant
    if not nearby.empty:
        closest = nearby.iloc[0]
        print(f"\nClosest restaurant: {closest['restaurant_name']}")
        print(f"Cuisine: {closest['cuisine_type']}")
        print(f"Rating: {closest['rating']}")
        print(f"Walking time: {closest['walking_time_mins']} minutes")
        print(f"Distance: {closest['walking_distance_meters']} meters")
        print(f"Google Maps: {closest['google_maps_url']}")
        print("\nWalking directions:")
        for step in closest['detailed_steps']:
            print(f"\n- {step['instruction']}")
            print(f"  ({step['distance']}, {step['duration']})")
    else:
        print("\nNo nearby restaurants found!") 