import requests
from bs4 import BeautifulSoup
from datetime import datetime
import time
import pandas as pd

class InfatuationScraper:
    def __init__(self):
        """Initialize the scraper"""
        self.base_url = "https://www.theinfatuation.com"
        self.search_url = f"{self.base_url}/london/search"
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }

    def search_restaurant(self, restaurant_name):
        """Search for a restaurant on The Infatuation"""
        try:
            params = {
                'query': restaurant_name
            }
            response = requests.get(self.search_url, params=params, headers=self.headers)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            search_results = soup.find_all('a', class_='venue-link')
            
            for result in search_results:
                # Get the restaurant name from the search result
                result_name = result.text.strip()
                
                # Check if names are similar
                if self._names_match(restaurant_name, result_name):
                    review_url = urljoin(self.base_url, result['href'])
                    return review_url
            
            return None
            
        except Exception as e:
            print(f"Error searching for {restaurant_name}: {str(e)}")
            return None

    def scrape_review(self, url):
        """Scrape the review content and 'Perfect For' features from a restaurant page"""
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract review data
            review_data = {
                'rating': None,
                'review_text': '',
                'review_date': None,
                'review_url': url,
                'features': []
            }
            
            # Try to find the rating
            rating_elem = soup.find('div', class_='rating')
            if rating_elem:
                rating_text = rating_elem.text.strip()
                try:
                    review_data['rating'] = float(rating_text)
                except:
                    pass
            
            # Try to find the review text
            review_content = soup.find('div', class_='venue-review')
            if review_content:
                review_data['review_text'] = review_content.text.strip()
            
            # Try to find the review date
            date_elem = soup.find('time')
            if date_elem:
                review_data['review_date'] = date_elem.get('datetime')
            
            # Find "Perfect For" section
            perfect_for_heading = soup.find(lambda tag: tag.name in ['h2', 'h3', 'h4'] 
                                          and 'Perfect For' in tag.text)
            
            if perfect_for_heading:
                features_container = perfect_for_heading.find_next(['div', 'ul', 'section'])
                if features_container:
                    feature_tags = features_container.find_all(['a', 'span', 'li'])
                    features = []
                    for tag in feature_tags:
                        feature_text = tag.text.strip()
                        if feature_text and not feature_text.isspace():
                            features.append(feature_text)
                    
                    review_data['features'] = list(set(features))
                    print(f"Found features: {review_data['features']}")
            
            return review_data
            
        except Exception as e:
            print(f"Error scraping review from {url}: {str(e)}")
            return None

    def _names_match(self, name1, name2):
        """Check if restaurant names match, accounting for minor differences"""
        def clean_name(name):
            name = re.sub(r'[^\w\s]', '', name.lower())
            common_words = ['restaurant', 'cafe', 'bar', 'the', 'and', '&']
            name_words = name.split()
            return ' '.join(word for word in name_words if word not in common_words)
        
        return clean_name(name1) == clean_name(name2)

    def process_restaurants(self, restaurants_df):
        """Process all restaurants and save reviews and features to CSV"""
        all_reviews = []
        all_features = []
        
        total_restaurants = len(restaurants_df)
        print(f"\nProcessing {total_restaurants} restaurants")
        
        for index, row in restaurants_df.iterrows():
            restaurant_name = row['Name']
            print(f"\n[{index + 1}/{total_restaurants}] Processing: {restaurant_name}")
            
            # Search for the restaurant
            review_url = self.search_restaurant(restaurant_name)
            
            if review_url:
                print(f"Found review URL: {review_url}")
                
                # Scrape the review and features
                review_data = self.scrape_review(review_url)
                
                if review_data:
                    # Prepare review data for CSV
                    review_entry = {
                        'restaurant_name': restaurant_name,
                        'rating': review_data['rating'],
                        'review_text': review_data['review_text'],
                        'review_date': review_data['review_date'],
                        'review_url': review_data['review_url'],
                        'source': 'The Infatuation',
                        'scraped_at': datetime.now().isoformat()
                    }
                    
                    all_reviews.append(review_entry)
                    print("✓ Review data collected")
                    
                    # Handle features
                    if review_data['features']:
                        for feature in review_data['features']:
                            feature_entry = {
                                'restaurant_name': restaurant_name,
                                'feature': feature,
                                'feature_type': 'Perfect For',
                                'source': 'The Infatuation',
                                'scraped_at': datetime.now().isoformat()
                            }
                            all_features.append(feature_entry)
                        print(f"✓ Collected {len(review_data['features'])} features")
                else:
                    print("✗ No review data found")
            else:
                print("✗ No review found")
            
            # Be nice to the server
            time.sleep(2)
        
        # Save to CSV files
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        if all_reviews:
            reviews_df = pd.DataFrame(all_reviews)
            reviews_filename = f'infatuation_reviews_{timestamp}.csv'
            reviews_df.to_csv(reviews_filename, index=False, encoding='utf-8')
            print(f"\n✓ Saved {len(all_reviews)} reviews to {reviews_filename}")
        
        if all_features:
            features_df = pd.DataFrame(all_features)
            features_filename = f'infatuation_features_{timestamp}.csv'
            features_df.to_csv(features_filename, index=False, encoding='utf-8')
            print(f"✓ Saved {len(all_features)} features to {features_filename}")
        
        # Print summary
        print("\n=== Summary ===")
        print(f"Total restaurants processed: {total_restaurants}")
        print(f"Reviews found: {len(all_reviews)}")
        print(f"Features found: {len(all_features)}")

if __name__ == "__main__":
    # Read the restaurants CSV
    restaurants_df = pd.read_csv("/Users/zara.thomas/PycharmProjects/NomNomNow/FlutterFlow/flutterflow/ConciergeX/PythonPrep/Restaurants_Enriched.csv")
    
    # Initialize scraper
    scraper = InfatuationScraper()
    
    # Start scraping
    scraper.process_restaurants(restaurants_df)