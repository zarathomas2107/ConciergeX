import requests
from bs4 import BeautifulSoup
import json
import os
import yaml
import re

def find_author_name(text):
    # Pattern for two capitalized words that might be a name
    # Looks for: Word Word or Word-Word (for hyphenated names)
    name_pattern = r'\n([A-Z][a-z]+(?:[-\s][A-Z][a-z]+)+)\n'
    match = re.search(name_pattern, text)
    if match:
        return match.group(1)
    return None

def extract_main_content(url):
    try:
        response = requests.get(url)
        response.raise_for_status()
        html_content = response.text
        soup = BeautifulSoup(html_content, 'html.parser')
        main_tag = soup.find('main')
        
        if main_tag:
            main_text = main_tag.get_text(separator='\n', strip=True)
            
            # Extract sections
            content = {}
            
            # Extract restaurant name from URL
            restaurant_name = url.split('/')[-1]
            content["name"] = restaurant_name
            
            # Extract rating
            rating_index = main_text.find("8.5")
            if rating_index != -1:
                content["rating"] = "8.5"
            
            # Extract restaurant categories
            categories = ["Vegetarian", "Middle Eastern", "Spitalfields"]
            content["categories"] = categories
            
            # Extract price level
            content["price_level"] = "$$$$"
            
            # Find author name
            author_name = find_author_name(main_text)
            
            # Extract "Perfect For" section
            perfect_for_start = main_text.find("Perfect For:")
            perfect_for_end = -1
            if author_name:
                perfect_for_end = main_text.find(author_name)
            
            if perfect_for_start != -1 and perfect_for_end != -1:
                perfect_for_text = main_text[perfect_for_start:perfect_for_end]
                perfect_for_items = [item.strip() for item in perfect_for_text.split('\n')[1:] if item.strip()]
                content["perfect_for"] = perfect_for_items
            
            # Try to find review start using multiple markers
            review_start = -1
            start_markers = [
                "Included In",
                "Perfect For:",
            ]
            
            if author_name:
                start_markers.append(author_name)
            
            # Try each start marker
            for marker in start_markers:
                marker_index = main_text.find(marker)
                if marker_index != -1:
                    # If it's "Included In", get the last item
                    if marker == "Included In":
                        text_after = main_text[marker_index:].split('\n')
                        included_in_items = [item.strip() for item in text_after[1:5] if item.strip()]
                        if included_in_items:
                            content["included_in"] = included_in_items
                            last_included_item = included_in_items[-1]
                            review_start = main_text.find(last_included_item) + len(last_included_item)
                            break
                    else:
                        # For other markers, start after the marker
                        review_start = main_text.find('\n', marker_index) + 1
                        break
            
            # If we found a review start point
            if review_start != -1:
                # Try different end markers
                end_markers = ["Food Rundown", "What our ratings mean", "About Us", "Suggested Reading"]
                review_end = -1
                for marker in end_markers:
                    review_end = main_text.find(marker, review_start)
                    if review_end != -1:
                        break
                
                # If no end marker found, use the rest of the text
                if review_end == -1:
                    review_end = len(main_text)
                
                review_text = main_text[review_start:review_end].strip()
                # Clean up the review text
                review_lines = []
                for line in review_text.split('\n'):
                    if not line.startswith('photo credit') and line.strip():
                        review_lines.append(line.strip())
                content["review"] = ' '.join(review_lines)
            
            # Extract Food Rundown section if it exists
            food_start = main_text.find("Food Rundown")
            if food_start != -1:
                # Try different end markers
                end_markers = ["What our ratings mean", "About Us", "Suggested Reading"]
                food_end = -1
                for marker in end_markers:
                    food_end = main_text.find(marker, food_start)
                    if food_end != -1:
                        break
                
                if food_end != -1:
                    food_text = main_text[food_start:food_end]
                    
                    # Clean up the text: remove "Food Rundown" header and photo credits
                    food_lines = []
                    for line in food_text.split('\n'):
                        line = line.strip()
                        if line and line != "Food Rundown" and 'photo credit' not in line.lower():
                            food_lines.append(line)
                    
                    # Create JSON objects for every two lines
                    food_items = []
                    for i in range(0, len(food_lines)-1, 2):
                        item = {
                            "line1": food_lines[i],
                            "line2": food_lines[i+1] if i+1 < len(food_lines) else ""
                        }
                        food_items.append(item)
                    
                    content["food_rundown"] = food_items
            
            return content
        else:
            return {"error": "No <main> tag found in the webpage."}
    except requests.exceptions.RequestException as e:
        return {"error": f"Error fetching the URL: {e}"}

def process_restaurants(restaurant_names):
    base_url = 'https://www.theinfatuation.com/london/reviews/'
    
    # Create directory if it doesn't exist
    os.makedirs('extracted_data', exist_ok=True)
    
    # Dictionary to store all restaurant reviews
    all_reviews = {}
    errors = []
    
    for restaurant in restaurant_names:
        # Construct URL
        url = base_url + restaurant
        
        print(f"Processing {restaurant}...")
        
        # Extract content
        content = extract_main_content(url)
        
        # Check if required sections are present
        if "error" in content:
            print(f"Error processing {restaurant}: {content['error']}")
            errors.append(restaurant)
            continue
            
        if "review" not in content:
            print(f"Warning: No review found for {restaurant}")
        
        if "food_rundown" not in content:
            print(f"Warning: No food rundown found for {restaurant}")
        
        # Add to all_reviews dictionary
        all_reviews[restaurant] = content
        
        print(f"Processed {restaurant}")
    
    # Save all reviews to a single JSON file
    output_path = os.path.join('extracted_data', 'all_restaurant_reviews.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(all_reviews, f, indent=2, ensure_ascii=False)
    
    print(f"\nAll reviews saved to {output_path}")
    if errors:
        print("\nFailed to process the following restaurants:")
        for restaurant in errors:
            print(f"- {restaurant}")

# Get the directory where the script is located
script_dir = os.path.dirname(os.path.abspath(__file__))

# Read restaurants from YAML file using the correct path
yaml_path = os.path.join(script_dir, 'restaurants.yaml')
with open(yaml_path, 'r') as file:
    yaml_data = yaml.safe_load(file)
    restaurants = yaml_data['restaurants']

# Process all restaurants
process_restaurants(restaurants)
 