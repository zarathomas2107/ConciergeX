from config import CONFIG

import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
from supabase import create_client
from datetime import datetime
import uuid
from googlemaps import Client as GoogleMaps
from typing import Optional, Dict, Any
import io
import re

class MenuScraper:
    def __init__(self, supabase_url, supabase_key, google_api_key, bucket_name="menu-pdfs"):
        """
        Initialize the scraper with Supabase and Google Places API credentials
        """
        print("Initializing Supabase client...")
        self.supabase_url = supabase_url  # Store URL
        self.supabase_key = supabase_key  # Store key
        self.supabase = create_client(supabase_url, supabase_key)
        self.gmaps = GoogleMaps(key=google_api_key)
        self.bucket_name = bucket_name
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        self._initialize_storage()

    def _initialize_storage(self):
        """Check if storage bucket exists"""
        try:
            # List all buckets and print them
            print("\nChecking Supabase connection...")
            print(f"Project URL: {self.supabase.rest_url}")  # Changed from base_url to rest_url
            
            print("\nAttempting to list buckets...")
            buckets = self.supabase.storage.list_buckets()
            print("Buckets response:", buckets)  # Print raw response
            
            if not buckets:
                print("\nNo buckets found. Please check:")
                print("1. You're using the service_role key (not anon key)")
                print("2. The bucket 'menu-pdfs' exists in your project")
                print("3. Your Supabase URL is correct")
                print("\nCurrent settings:")
                print(f"URL: {self.supabase.rest_url}")
                print(f"Key: {self.supabase_key[:10]}...")  # Show first 10 chars of key
                raise Exception("No buckets accessible")
            
            print("\nAvailable buckets:")
            for bucket in buckets:
                print(f"- {bucket.name}")
            
            bucket_exists = any(bucket.name == self.bucket_name for bucket in buckets)
            
            if not bucket_exists:
                print(f"\nError: Bucket '{self.bucket_name}' not found!")
                print("Available bucket names:", [b.name for b in buckets])
                raise Exception(f"Bucket '{self.bucket_name}' does not exist")
            
            print(f"\nSuccessfully connected to bucket: {self.bucket_name}")
            
        except Exception as e:
            print(f"\nError accessing storage: {str(e)}")
            raise

    def _fetch_restaurant_details(self, name: str, url: str) -> Optional[Dict[str, Any]]:
        """
        Fetch restaurant details from Google Places API using the Restaurants_Enriched schema
        """
        try:
            places_result = self.gmaps.places(name)
            
            if not places_result['results']:
                print(f"No Google Places results found for: {name}")
                return None
            
            place = places_result['results'][0]
            place_details = self.gmaps.place(place['place_id'])['result']
            
            # Get the website from Google Places if available, otherwise use provided URL
            google_website = place_details.get('website', '')
            website_url = google_website if google_website else url
            
            # Match schema and include website
            restaurant_data = {
                'RestaurantID': place['place_id'],
                'Name': place_details.get('name', name),
                'CuisineType': None,  # Left as null as requested
                'Country': 'UK',
                'City': 'London',
                'Address': place_details.get('formatted_address', ''),
                'Rating': place_details.get('rating', 0.0),
                'BusinessStatus': place_details.get('business_status', 'OPERATIONAL'),
                'Latitude': place_details['geometry']['location']['lat'],
                'Longitude': place_details['geometry']['location']['lng'],
                'PriceLevel': place_details.get('price_level', None),
                'website': website_url  # Add website URL
            }
            
            return restaurant_data
            
        except Exception as e:
            print(f"Error fetching restaurant details from Google Places: {str(e)}")
            return None

    def get_or_create_restaurant(self, name: str, url: str) -> str:
        """
        Get existing restaurant or create new one with Google Places data
        Returns RestaurantID
        """
        try:
            # Check if restaurant exists by name
            result = self.supabase.table('restaurants').select('RestaurantID').eq('Name', name).execute()
            
            if result.data and len(result.data) > 0:
                # Update website if it exists
                self.supabase.table('restaurants').update(
                    {'website': url}
                ).eq('RestaurantID', result.data[0]['RestaurantID']).execute()
                return result.data[0]['RestaurantID']
            
            # Fetch details from Google Places API
            restaurant_data = self._fetch_restaurant_details(name, url)
            
            if not restaurant_data:
                # Fallback to basic data if Google Places API fails
                restaurant_data = {
                    'RestaurantID': str(uuid.uuid4()),
                    'Name': name,
                    'CuisineType': None,
                    'Country': 'UK',
                    'City': 'London',
                    'Address': '',
                    'Rating': None,
                    'BusinessStatus': 'OPERATIONAL',
                    'Latitude': None,
                    'Longitude': None,
                    'PriceLevel': None,
                    'website': url  # Include the provided URL
                }
            
            # Create new restaurant
            result = self.supabase.table('restaurants').insert(restaurant_data).execute()
            return result.data[0]['RestaurantID']

        except Exception as e:
            print(f"Error managing restaurant entry: {str(e)}")
            raise

    def _generate_filename(self, original_name, restaurant_name):
        """Generate a unique filename for the PDF"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        clean_name = ''.join(c if c.isalnum() else '_' for c in restaurant_name)
        return f"{clean_name}_{timestamp}.pdf"

    def save_to_supabase(self, pdf_content, filename, restaurant_id, original_menu_name):
        """
        Save PDF to Supabase storage and record metadata in database
        """
        try:
            print(f"Attempting to upload file: {filename}")
            
            # Upload PDF to storage
            file_path = filename
            
            # Convert PDF content to bytes if it isn't already
            if not isinstance(pdf_content, bytes):
                pdf_content = pdf_content.encode()
            
            print(f"Uploading file of size: {len(pdf_content)} bytes")
            
            # Try to upload, if file exists, append timestamp to filename
            try:
                upload_response = self.supabase.storage.from_(self.bucket_name).upload(
                    file_path,
                    pdf_content,
                    {'content-type': 'application/pdf'}
                )
            except Exception as e:
                if 'already exists' in str(e):
                    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                    file_path = f"{filename.replace('.pdf', '')}_{timestamp}.pdf"
                    upload_response = self.supabase.storage.from_(self.bucket_name).upload(
                        file_path,
                        pdf_content,
                        {'content-type': 'application/pdf'}
                    )
                else:
                    raise
            
            print(f"Upload response: {upload_response}")
            
            # Get the public URL
            public_url = self.supabase.storage.from_(self.bucket_name).get_public_url(file_path)

            # Store menu metadata in database with exact column names
            menu_data = {
                'restaurant_id': restaurant_id,
                'menu_url': public_url,
                'filename': file_path,
                'menu_name': original_menu_name
                # created_at will be set automatically by the database
            }
            
            print("Inserting into database with data:", menu_data)
            
            try:
                db_response = self.supabase.table('restaurant_menus').insert(menu_data).execute()
                print(f"Database insert successful: {db_response}")
                return public_url
            except Exception as db_error:
                print(f"Database error details: {str(db_error)}")
                if hasattr(db_error, 'response'):
                    print(f"Response: {db_error.response.text if hasattr(db_error.response, 'text') else db_error.response}")
                raise
            
        except Exception as e:
            print(f"Error saving to Supabase: {str(e)}")
            print(f"Error type: {type(e)}")
            if hasattr(e, 'response'):
                print(f"Response: {e.response.text if hasattr(e.response, 'text') else e.response}")
            return None

    def create_menus_table(self):
        """
        Create the restaurant_menus table if it doesn't exist
        """
        create_table_sql = """
        CREATE TABLE IF NOT EXISTS restaurant_menus (
            id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
            restaurant_id text REFERENCES restaurants(RestaurantID),
            menu_url text,
            filename text,
            menu_name text,
            created_at timestamp with time zone DEFAULT now(),
            CONSTRAINT fk_restaurant 
                FOREIGN KEY(restaurant_id) 
                REFERENCES restaurants(RestaurantID)
                ON DELETE CASCADE
        );
        """
        
        try:
            self.supabase.table('restaurant_menus').select('id').limit(1).execute()
        except:
            print("Creating restaurant_menus table...")
            # You'll need to run this SQL in your Supabase SQL editor
            print("Please run this SQL in your Supabase SQL editor:")
            print(create_table_sql)
            raise Exception("restaurant_menus table needs to be created. See SQL above.")

    def scrape_menus(self, url, restaurant_name=None):
        """
        Scrape menus from the given URL and any menu-specific pages
        """
        if restaurant_name is None:
            restaurant_name = url.split('/')[2]

        try:
            print(f"\nAccessing website: {url}")
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # First, find all menu-related links
            menu_pages = set()  # Use set to avoid duplicates
            pdf_links = []
            
            # Keywords that might indicate a menu page or PDF
            menu_keywords = ['menu', 'food', 'drink', 'wine', 'dinner', 'lunch', 'brunch', 'breakfast']
            
            # Find all links
            for link in soup.find_all('a', href=True):
                href = link['href']
                link_text = link.text.lower().strip()
                
                # Make URL absolute
                full_url = urljoin(url, href)
                
                # Skip external links except PDFs
                if not full_url.startswith(url) and not href.lower().endswith('.pdf'):
                    continue
                
                # Check if it's a PDF
                if href.lower().endswith('.pdf'):
                    if any(keyword in link_text or keyword in href.lower() for keyword in menu_keywords):
                        menu_name = link.text.strip() if link.text.strip() else href.split('/')[-1]
                        pdf_links.append({'url': full_url, 'name': menu_name})
                
                # Check if it might be a menu page
                elif any(keyword in link_text or keyword in href.lower() for keyword in menu_keywords):
                    menu_pages.add(full_url)
            
            # Process each menu page found
            for menu_page in menu_pages:
                try:
                    print(f"Checking menu page: {menu_page}")
                    menu_response = requests.get(menu_page, headers=self.headers)
                    menu_response.raise_for_status()
                    menu_soup = BeautifulSoup(menu_response.text, 'html.parser')
                    
                    # Look for PDFs on the menu page
                    for menu_link in menu_soup.find_all('a', href=True):
                        href = menu_link['href']
                        if href.lower().endswith('.pdf'):
                            full_url = urljoin(menu_page, href)
                            menu_name = menu_link.text.strip() if menu_link.text.strip() else href.split('/')[-1]
                            pdf_links.append({'url': full_url, 'name': menu_name})
                
                except Exception as e:
                    print(f"Error accessing menu page {menu_page}: {str(e)}")
                    continue

            if not pdf_links:
                print("No menu PDFs found on the website or menu pages.")
                return []

            # Remove duplicates while preserving order
            seen_urls = set()
            unique_pdf_links = []
            for pdf in pdf_links:
                if pdf['url'] not in seen_urls:
                    seen_urls.add(pdf['url'])
                    unique_pdf_links.append(pdf)

            saved_menus = []
            restaurant_id = self.get_or_create_restaurant(restaurant_name, url)
            
            print(f"\nFound {len(unique_pdf_links)} unique menu PDFs to process")
            
            for pdf_link in unique_pdf_links:
                try:
                    print(f"\nProcessing menu: {pdf_link['name']}")
                    print(f"URL: {pdf_link['url']}")
                    
                    pdf_response = requests.get(pdf_link['url'], headers=self.headers)
                    pdf_response.raise_for_status()
                    
                    # Clean restaurant name and menu name
                    clean_restaurant = self._clean_filename(restaurant_name)
                    clean_menu = self._clean_filename(pdf_link['name'])
                    
                    # Generate filename
                    filename = f"{clean_restaurant}_{clean_menu}.pdf"
                    
                    print(f"Saving as: {filename}")
                    
                    public_url = self.save_to_supabase(
                        pdf_response.content,
                        filename,
                        restaurant_id,
                        pdf_link['name']  # Pass original menu name for database
                    )
                    
                    if public_url:
                        saved_menus.append({
                            'url': public_url,
                            'restaurant_id': restaurant_id,
                            'menu_name': pdf_link['name']
                        })
                        print(f"✓ Successfully uploaded: {filename}")
                    
                except Exception as e:
                    print(f"✗ Error processing {pdf_link['url']}: {str(e)}")
                    continue
            
            return saved_menus

        except Exception as e:
            print(f"Error accessing website: {str(e)}")
            return []

    def _clean_filename(self, name):
        """
        Clean filename to be storage-friendly
        """
        # Replace spaces and other characters with underscores
        clean = re.sub(r'[^\w\-]', '_', name)
        # Remove multiple consecutive underscores
        clean = re.sub(r'_+', '_', clean)
        # Remove leading/trailing underscores
        clean = clean.strip('_')
        return clean

    def scrape_restaurant_menus(self, restaurant_id: str = None):
        """
        Scrape menus for either a specific restaurant or all restaurants with websites
        """
        try:
            print("\nChecking for restaurants with websites...")
            
            # First check if we have any restaurants with websites
            query = self.supabase.table('restaurants').select('RestaurantID, Name, website')
            result = query.not_.is_('website', 'null').execute()
            
            # If no restaurants have websites, update them first
            if not result.data:
                print("No restaurants with websites found. Updating websites first...")
                self.update_restaurant_websites()
                
                # Query again after update
                result = query.not_.is_('website', 'null').execute()
            
            total_restaurants = len(result.data)
            print(f"\nFound {total_restaurants} restaurants with websites")
            
            if not result.data:
                print("Still no restaurants with websites found after update.")
                return []

            all_saved_menus = []
            for index, restaurant in enumerate(result.data, 1):
                if not restaurant.get('website'):
                    continue
                    
                print(f"\n[{index}/{total_restaurants}] Processing: {restaurant.get('Name')}")
                print(f"Website: {restaurant.get('website')}")
                
                try:
                    saved_menus = self.scrape_menus(
                        url=restaurant.get('website'),
                        restaurant_name=restaurant.get('Name')
                    )
                    
                    if saved_menus:
                        all_saved_menus.extend(saved_menus)
                        print(f"✓ Found {len(saved_menus)} menus")
                    else:
                        print("✗ No menus found")
                        
                except Exception as e:
                    print(f"✗ Error processing {restaurant.get('Name')}: {str(e)}")
                    continue
            
            # Print summary
            print("\n=== Summary ===")
            print(f"Total restaurants processed: {total_restaurants}")
            print(f"Total menus found: {len(all_saved_menus)}")
            print(f"Restaurants with menus: {len(set(menu['restaurant_id'] for menu in all_saved_menus))}")
            
            return all_saved_menus

        except Exception as e:
            print(f"Error processing restaurants: {str(e)}")
            return []

    def update_restaurant_websites(self):
        """
        Update website URLs for all restaurants using Google Places API
        """
        try:
            print("\nUpdating restaurant websites...")
            
            # Get all restaurants
            result = self.supabase.table('restaurants').select('*').execute()
            
            updated_count = 0
            for restaurant in result.data:
                print(f"\nProcessing: {restaurant['Name']}")
                
                try:
                    # Search for the restaurant
                    places_result = self.gmaps.places(
                        f"{restaurant['Name']} {restaurant['Address']}"  # Include address for better accuracy
                    )
                    
                    if not places_result['results']:
                        print(f"No Google Places results found for: {restaurant['Name']}")
                        continue
                    
                    # Get the first result
                    place = places_result['results'][0]
                    place_details = self.gmaps.place(place['place_id'])['result']
                    
                    # Get website from Google Places
                    website = place_details.get('website')
                    
                    if website:
                        print(f"Found website: {website}")
                        # Update the restaurant record
                        self.supabase.table('restaurants').update(
                            {'website': website}
                        ).eq('RestaurantID', restaurant['RestaurantID']).execute()
                        updated_count += 1
                    else:
                        print("No website found in Google Places")
                
                except Exception as e:
                    print(f"Error processing restaurant {restaurant['Name']}: {str(e)}")
                    continue
            
            print(f"\nUpdated websites for {updated_count} restaurants")
            
        except Exception as e:
            print(f"Error updating restaurant websites: {str(e)}")

if __name__ == "__main__":
    # Your credentials here
    SUPABASE_URL = "https://snxksagtvimkrngjueal.supabase.co"
    SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNueGtzYWd0dmlta3JuZ2p1ZWFsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNTIzNjQyOCwiZXhwIjoyMDUwODEyNDI4fQ.K9aigylflesDC4EMjUYjmJcRlLYIZdgtXIpZiHRaTj0"
    GOOGLE_API_KEY = "AIzaSyDVq2F546uy7O72qnC6F4lA22uG3nwuvB8"
    
    # Initialize scraper
    scraper = MenuScraper(SUPABASE_URL, SUPABASE_KEY, GOOGLE_API_KEY)
    
    # Start scraping all restaurants
    print("Starting menu scraping process...")
    saved_menus = scraper.scrape_restaurant_menus('all')
    
    # Print detailed results
    if saved_menus:
        print("\nDetailed results:")
        restaurants_with_menus = {}
        for menu in saved_menus:
            rest_id = menu['restaurant_id']
            if rest_id not in restaurants_with_menus:
                restaurants_with_menus[rest_id] = []
            restaurants_with_menus[rest_id].append(menu['url'])
        
        for rest_id, menu_urls in restaurants_with_menus.items():
            print(f"\nRestaurant ID: {rest_id}")
            print(f"Number of menus: {len(menu_urls)}")
            for url in menu_urls:
                print(f"- {url}")
    else:
        print("\nNo menus were found or saved.")    