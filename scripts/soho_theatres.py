from config import CONFIG

import googlemaps
from datetime import datetime
import pandas as pd
import time

class TheatreFinder:
    def __init__(self, api_key):
        self.gmaps = googlemaps.Client(key=api_key)
        self.soho_location = {
            'lat': 51.5137,  # Soho approximate center latitude
            'lng': -0.1349   # Soho approximate center longitude
        }
        self.soho_radius = 800  # meters (covers Soho area)

    def find_theatres(self):
        """Find all theatres in Soho area"""
        all_theatres = []
        
        # Search keywords
        keywords = ['theatre', 'theater', 'playhouse']
        
        for keyword in keywords:
            print(f"\nSearching for '{keyword}' in Soho...")
            
            try:
                # Perform nearby search
                results = self.gmaps.places_nearby(
                    location=self.soho_location,
                    radius=self.soho_radius,
                    keyword=keyword,
                    type='establishment'
                )
                
                # Process initial results
                all_theatres.extend(self._process_results(results.get('results', [])))
                
                # Get next pages while available
                while 'next_page_token' in results:
                    time.sleep(2)  # Wait for token to be valid
                    results = self.gmaps.places_nearby(
                        location=self.soho_location,
                        radius=self.soho_radius,
                        keyword=keyword,
                        page_token=results['next_page_token']
                    )
                    all_theatres.extend(self._process_results(results.get('results', [])))
                
            except Exception as e:
                print(f"Error searching for {keyword}: {str(e)}")
                continue
        
        # Remove duplicates based on place_id
        unique_theatres = {t['place_id']: t for t in all_theatres}.values()
        
        # Convert to DataFrame
        df = pd.DataFrame(list(unique_theatres))
        
        # Sort by rating (if available)
        if 'rating' in df.columns:
            df = df.sort_values('rating', ascending=False)
        
        # Save to CSV
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'soho_theatres_{timestamp}.csv'
        df.to_csv(filename, index=False, encoding='utf-8')
        
        print(f"\n✓ Found {len(df)} unique theatres")
        print(f"✓ Saved results to {filename}")
        
        return df

    def _process_results(self, results):
        """Process and enrich place results"""
        processed_results = []
        
        for place in results:
            try:
                # Get detailed place information
                details = self.gmaps.place(place['place_id'])['result']
                
                theatre_info = {
                    'name': details.get('name', ''),
                    'place_id': details.get('place_id', ''),
                    'address': details.get('formatted_address', ''),
                    'phone': details.get('formatted_phone_number', ''),
                    'website': details.get('website', ''),
                    'rating': details.get('rating', None),
                    'user_ratings_total': details.get('user_ratings_total', 0),
                    'latitude': details.get('geometry', {}).get('location', {}).get('lat', None),
                    'longitude': details.get('geometry', {}).get('location', {}).get('lng', None),
                    'types': ', '.join(details.get('types', [])),
                    'price_level': details.get('price_level', None),
                    'opening_hours': str(details.get('opening_hours', {}).get('weekday_text', [])),
                    'google_maps_url': details.get('url', ''),
                }
                
                # Check if it's in Soho (can be approximate based on postal code or address)
                if 'Soho' in details.get('formatted_address', '') or 'W1' in details.get('formatted_address', ''):
                    processed_results.append(theatre_info)
                    print(f"✓ Found: {theatre_info['name']}")
                
            except Exception as e:
                print(f"Error processing place: {str(e)}")
                continue
            
            # Be nice to the API
            time.sleep(1)
        
        return processed_results

if __name__ == "__main__":
    # Your Google API key
    GOOGLE_API_KEY = "AIzaSyDVq2F546uy7O72qnC6F4lA22uG3nwuvB8"
    
    # Initialize finder
    finder = TheatreFinder(GOOGLE_API_KEY)
    
    # Find theatres
    theatres_df = finder.find_theatres()
    
    # Print summary
    if not theatres_df.empty:
        print("\n=== Summary of Found Theatres ===")
        print(f"Total theatres: {len(theatres_df)}")
        if 'rating' in theatres_df.columns:
            avg_rating = theatres_df['rating'].mean()
            print(f"Average rating: {avg_rating:.1f}")
        print("\nTop rated theatres:")
        print(theatres_df[['name', 'rating', 'address']].head().to_string()) 