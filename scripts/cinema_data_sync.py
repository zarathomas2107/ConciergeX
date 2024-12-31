from config import CONFIG

import requests
from datetime import datetime, timedelta
import os
from supabase import create_client
import time
import json
import traceback
import re  # Add this to the imports at the top

# Initialize Supabase client
supabase_url = "https://snxksagtvimkrngjueal.supabase.co"
supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNueGtzYWd0dmlta3JuZ2p1ZWFsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNTIzNjQyOCwiZXhwIjoyMDUwODEyNDI4fQ.K9aigylflesDC4EMjUYjmJcRlLYIZdgtXIpZiHRaTj0"
supabase = create_client(supabase_url, supabase_key)

# API Configuration
API_KEY = "wp4G62uS4BnEzhHw8Z7G86hh"
BASE_URL = "https://uk-cinema-api.co.uk/api/v1"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}"
}

# Expanded London coordinates (approximate bounding box)
LONDON_BOUNDS = {
    'min_lat': 51.28,
    'max_lat': 51.686,
    'min_lon': -0.55,  # Expanded west
    'max_lon': 0.35    # Expanded east
}

def is_in_london(latitude, longitude):
    """Check if coordinates are within London bounds"""
    try:
        lat = float(latitude)
        lon = float(longitude)
        in_london = (LONDON_BOUNDS['min_lat'] <= lat <= LONDON_BOUNDS['max_lat'] and
                    LONDON_BOUNDS['min_lon'] <= lon <= LONDON_BOUNDS['max_lon'])
        
        # Debug print for each cinema location check
        print(f"Checking location: {lat}, {lon} - In London: {in_london}")
        if not in_london:
            print(f"Outside bounds: lat [{LONDON_BOUNDS['min_lat']} to {LONDON_BOUNDS['max_lat']}], " 
                  f"lon [{LONDON_BOUNDS['min_lon']} to {LONDON_BOUNDS['max_lon']}]")
        return in_london
    except (TypeError, ValueError) as e:
        print(f"Error checking location: {latitude}, {longitude} - {str(e)}")
        return False

def extract_postcode(address):
    """Extract postcode from address string using UK postcode pattern"""
    if not address:
        return None
        
    # UK postcode pattern
    # Examples: EC1A 1BB, W1A 1HQ, M1 1AA, B33 8TH, CR2 6XH, DN55 1PT
    postcode_pattern = r'[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}'
    
    # Search for postcode in address
    match = re.search(postcode_pattern, address.upper())
    if match:
        return match.group(0)
    
    return None

def is_london_postcode(postcode):
    """Check if a postcode is in London"""
    if not postcode:
        return False
    
    # Expanded list of London and Greater London postcode areas
    london_areas = [
        'N', 'NW', 'E', 'EC', 'SE', 'SW', 'W', 'WC',    # Central London
        'BR', 'CR', 'DA', 'EN', 'HA', 'IG', 'KT',       # Greater London
        'RM', 'SM', 'TW', 'UB', 'WD', 'TN', 'CM',       # Extended Greater London
        'AL', 'SL', 'RH', 'GU', 'HP', 'SS', 'ME'        # Surrounding areas
    ]
    
    try:
        # Clean and uppercase the postcode
        postcode = postcode.strip().upper()
        # Extract the postcode area (first 1-2 characters)
        postcode_area = ''.join(c for c in postcode if c.isalpha())[:2]
        
        is_london = postcode_area in london_areas
        print(f"Checking postcode: {postcode} (area: {postcode_area}) - Is London: {is_london}")
        return is_london
        
    except Exception as e:
        print(f"Error processing postcode {postcode}: {str(e)}")
        return False

def fetch_film_details(film_id):
    """Fetch film details from the API"""
    try:
        response = requests.get(f"{BASE_URL}/films/{film_id}", headers=HEADERS)
        response.raise_for_status()
        film_data = response.json()
        return film_data.get('title', 'Unknown Movie')
    except:
        return 'Unknown Movie'

def fetch_cinemas():
    """Fetch and filter London cinemas"""
    all_cinemas = fetch_all_cinemas()
    
    print("\nAll cinemas before London filtering:")
    for cinema in all_cinemas:
        name = cinema.get('name')
        address = cinema.get('address', '')
        extracted_postcode = extract_postcode(address)
        print(f"\nCinema: {name}")
        print(f"Address: {address}")
        print(f"Extracted Postcode: {extracted_postcode}")
        print(f"Chain: {cinema.get('chain', 'Unknown chain')}")
        
        # Add extracted postcode to cinema data
        cinema['postcode'] = extracted_postcode
    
    print("\nFiltering for London cinemas...")
    london_cinemas = [
        cinema for cinema in all_cinemas
        if is_london_postcode(cinema.get('postcode', ''))
    ]
    
    print(f"\nFound {len(london_cinemas)} cinemas in London out of {len(all_cinemas)} total cinemas")
    print("\nLondon cinemas:")
    for cinema in london_cinemas:
        print(f"- {cinema.get('name')}: {cinema.get('address')} (Postcode: {cinema.get('postcode')})")
    
    return london_cinemas

def fetch_all_cinemas():
    """Fetch all cinemas using pagination"""
    all_cinemas = []
    page = 1
    
    try:
        while True:
            print(f"\nFetching page {page} of cinemas...")
            
            params = {
                "page": str(page),
                "items": "100"  # Changed from per_page to items
            }
            
            response = requests.get(f"{BASE_URL}/cinemas", headers=HEADERS, params=params)
            response.raise_for_status()
            data = response.json()
            
            if not data:
                print("No cinemas in response, ending pagination")
                break
                
            all_cinemas.extend(data)
            print(f"Retrieved {len(data)} cinemas from page {page}")
            print(f"Total cinemas so far: {len(all_cinemas)}")
            
            # If we got less than the requested items, we're on the last page
            if len(data) < 100:
                print("Reached last page (incomplete page)")
                break
                
            page += 1
            time.sleep(1)  # Rate limiting
            
        print(f"\nTotal cinemas fetched: {len(all_cinemas)}")
        return all_cinemas
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching cinemas: {str(e)}")
        print(f"Response: {response.text if 'response' in locals() else 'No response'}")
        return []

def fetch_all_showtimes(cinema_id, start_date, end_date):
    """Fetch all showtimes for a cinema using pagination"""
    all_showtimes = []
    page = 1
    
    try:
        while True:
            print(f"Fetching showtimes page {page}...")
            
            params = {
                "cinema_id": cinema_id,
                "start_date": start_date.strftime("%Y-%m-%d"),
                "end_date": end_date.strftime("%Y-%m-%d"),
                "page": str(page),
                "items": "100"  # Changed from per_page to items
            }
            
            response = requests.get(f"{BASE_URL}/showtimes", headers=HEADERS, params=params)
            response.raise_for_status()
            data = response.json()
            
            if not data:
                print("No showtimes in response, ending pagination")
                break
                
            all_showtimes.extend(data)
            print(f"Retrieved {len(data)} showtimes from page {page}")
            print(f"Total showtimes so far: {len(all_showtimes)}")
            
            # If we got less than the requested items, we're on the last page
            if len(data) < 100:
                print("Reached last page (incomplete page)")
                break
                
            page += 1
            time.sleep(1)
            
        return all_showtimes
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching showtimes: {str(e)}")
        print(f"Response: {response.text if 'response' in locals() else 'No response'}")
        return []

def sync_data():
    start_date = datetime.now()
    end_date = start_date + timedelta(days=7)  # Reduced to 7 days for testing
    
    london_cinemas = fetch_cinemas()
    film_titles = {}  # Cache for film titles
    
    for cinema in london_cinemas:
        try:
            cinema_data = {
                "id": str(cinema.get("id", "")),
                "name": cinema.get("name", "Unknown"),
                "address": cinema.get("address", ""),
                "postcode": cinema.get("postcode", ""),
                "chain": cinema.get("chain", ""),
                "location": f"POINT({cinema.get('longitude', 0)} {cinema.get('latitude', 0)})",
                "website": cinema.get("link", "")
            }
            
            if cinema_data["id"]:
                result = supabase.table("cinemas").upsert(cinema_data).execute()
                print(f"Inserted cinema: {cinema_data['name']}")
                
        except Exception as e:
            print(f"Error inserting cinema {cinema.get('id', 'unknown')}:")
            print(f"Error details: {str(e)}")
    
    # Process showtimes
    for cinema in london_cinemas:
        try:
            cinema_id = str(cinema.get("id", ""))
            if not cinema_id:
                continue
                
            print(f"\nFetching showtimes for {cinema.get('name')}...")
            showtimes = fetch_all_showtimes(cinema_id, start_date, end_date)
            
            print(f"Processing {len(showtimes)} showtimes for {cinema.get('name')}")
            
            for showtime in showtimes:
                try:
                    film_id = str(showtime.get("film_id", ""))
                    
                    # Get film title from cache or API
                    if film_id not in film_titles:
                        film_titles[film_id] = fetch_film_details(film_id)
                    
                    showtime_data = {
                        "id": str(showtime.get("id", "")),
                        "cinema_id": cinema_id,
                        "movie_title": film_titles[film_id],
                        "start_time": showtime.get("showing_at"),
                        "end_time": None,  # API doesn't provide end time
                        "screen": "",  # API doesn't provide screen number
                        "booking_link": showtime.get("booking_link", ""),
                        "sold_out": showtime.get("sold_out", False)
                    }
                    
                    if showtime_data["id"] and showtime_data["start_time"]:
                        result = supabase.table("showtimes").upsert(showtime_data).execute()
                        print(f"Inserted showtime: {showtime_data['movie_title']} at {showtime_data['start_time']}")
                    
                except Exception as e:
                    print(f"Error inserting showtime:")
                    print(f"Error details: {str(e)}")
            
            print(f"Completed processing showtimes for {cinema.get('name')}")
            
        except Exception as e:
            print(f"Error processing cinema {cinema_id}:")
            print(f"Error details: {str(e)}")
        
        time.sleep(1)  # Rate limiting between cinemas

if __name__ == "__main__":
    if not all([supabase_url, supabase_key, API_KEY]):
        print("Error: Missing environment variables")
    else:
        sync_data()
        print("\nSync completed!")