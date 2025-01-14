import os
import PyPDF2
from openai import OpenAI
import re
import json
import sys
import csv
import pandas as pd

# Initialize OpenAI client with API key from environment variable
client = OpenAI(
    api_key=os.environ.get("OPENAI_API_KEY")
)

def clean_menu_text(text):
    """Clean and format menu text to properly handle multi-line items."""
    # Split into lines and clean each line
    lines = text.split('\n')
    cleaned_lines = []
    current_item = []
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Check if this line looks like a new menu item
        is_new_item = (
            # Starts with capital letter
            line[0].isupper() if line else False or
            # Has vegetarian markers
            any(marker in line.lower() for marker in ['(v)', '(vg)', '(ve)', ' v ', ' vg ', ' ve ']) or
            # Has a price
            '£' in line or
            # All previous lines are complete
            not current_item
        )
        
        if is_new_item and current_item:
            # Join previous item and add to list
            cleaned_lines.append(' | '.join(current_item))
            current_item = [line]
        else:
            current_item.append(line)
    
    # Add the last item if exists
    if current_item:
        cleaned_lines.append(' | '.join(current_item))
    
    return ' \n '.join(cleaned_lines)

def extract_text_from_pdf(pdf_path):
    """Extract text from PDF with improved error handling."""
    try:
        with open(pdf_path, 'rb') as file:
            # Create PDF reader object
            try:
                reader = PyPDF2.PdfReader(file)
            except Exception as e:
                print(f"Error creating PDF reader for {pdf_path}: {e}")
                return ""
            
            # Extract text from each page
            text = ""
            for i, page in enumerate(reader.pages):
                try:
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text + "\n"
                except Exception as e:
                    print(f"Error extracting text from page {i+1} in {pdf_path}: {e}")
                    continue
            
            # Clean and return the text
            cleaned_text = clean_menu_text(text.strip())
            if not cleaned_text:
                print(f"Warning: No text could be extracted from {pdf_path}")
            return cleaned_text
            
    except Exception as e:
        print(f"Error opening PDF {pdf_path}: {e}")
        return ""

def has_vegetarian_marker(item_text, restaurant_name=None):
    """Check if an item has common vegetarian markers or is a vegan substitute."""
    # Convert to lowercase for case-insensitive matching
    text = item_text.lower()
    
    # Common vegetarian markers
    markers = [
        r'\(v\)',          # (v)
        r'\(v/g\)',        # (v/g)
        r'\(vg\)',         # (vg)
        r'\(ve\)',         # (ve)
        r'\bv\b',          # v alone
        r'\bvg\b',         # vg alone
        r'\bve\b',         # ve alone
        r'vegetarian',     # word vegetarian
        r'\(vegetarian\)'  # (vegetarian)
    ]
    
    # Check for quoted items in vegan restaurants
    if restaurant_name and restaurant_name.lower() in VEGAN_RESTAURANTS:
        # Add patterns for single and double quoted meat terms
        meat_terms = ['chicken', 'fish', 'beef', 'pork', 'lamb', 'duck', 'prawns', 'shrimp', 'bacon', 'ham', 'seafood']
        for term in meat_terms:
            markers.extend([
                f"'{term}'",    # single quotes
                f'"{term}"',    # double quotes
                f"'{term}s'",   # plural with single quotes
                f'"{term}s"'    # plural with double quotes
            ])
    
    return any(re.search(pattern, text) for pattern in markers)

def load_misclassified_examples(file_path='misclassified_items.csv'):
    """Load misclassified items to use as examples for fine-tuning."""
    try:
        df = pd.read_csv(file_path)
        examples = []
        for _, row in df.iterrows():
            if row['corrected']:  # Only use items that have been manually reviewed
                example = {
                    'item': row['item'],
                    'category': row['category'],
                    'is_vegetarian': row['correct_classification'],
                    'explanation': row['reason']
                }
                examples.append(example)
        return examples
    except Exception as e:
        print(f"Error loading misclassified examples: {e}")
        return []

def classify_menu_items(menu_text):
    try:
        # Don't attempt classification if no text was extracted
        if not menu_text:
            print("No menu text provided for classification")
            return "[]"
            
        # Load fine-tuning examples
        examples = load_misclassified_examples()
        examples_text = ""
        if examples:
            examples_text = "Here are some example classifications:\n"
            for ex in examples[:5]:  # Use up to 5 examples
                examples_text += f"Item: {ex['item']}\n"
                examples_text += f"Category: {ex['category']}\n"
                examples_text += f"Is Vegetarian: {ex['is_vegetarian']}\n"
                examples_text += f"Explanation: {ex['explanation']}\n\n"
        
        # Clean up the text while preserving meaningful line breaks
        menu_text = re.sub(r'\s+', ' ', menu_text)
        
        # Check if there's actual menu content
        if len(menu_text.strip()) < 10:  # Arbitrary minimum length
            print("Menu text too short or empty")
            return "[]"
            
        prompt = f"""Analyze the following menu text and classify items as vegetarian or non-vegetarian.
        The text may contain menu items with descriptions on separate lines, joined by ' | '.
        
        {examples_text}
        
        Rules for classification:
        - Items with meat, fish, or seafood are non-vegetarian UNLESS they are clearly marked as substitutes
        - Items with eggs or dairy are vegetarian
        - Items marked with (v), (v/g), (vg), v, vg, or ve should be classified as vegetarian
        - Terms in quotes like 'chicken', "fish", 'beef' often indicate meat substitutes, especially in vegan restaurants
        - Common vegan substitutes include:
          * 'ribs', "wings", "beef", "chicken", "fish", "prawns", "lamb"
          * Items described as "veggie [meat]" or "vegan [meat]"
          * Items with quotes around meat terms
        - Consider both the item name and its description when classifying
        - If unsure about an item in a vegan/vegetarian restaurant, classify as vegetarian
        
        For each menu item, provide:
        1. The category (Main/Starter/Side)
        2. Whether it's vegetarian (true/false)
        3. The price if available (number only, no currency symbol)
        
        Format your response as a JSON array with these exact fields:
        [
            {{"item": "Item name with description", "category": "Category", "is_vegetarian": true/false, "price": number}}
        ]
        
        Menu text: {menu_text[:4000]}"""

        response = client.chat.completions.create(
            model="gpt-4",  # Using GPT-4 for better accuracy
            messages=[
                {"role": "system", "content": "You are a helpful assistant that analyzes restaurant menus and outputs only valid JSON arrays containing menu item classifications. You are particularly good at identifying vegan and vegetarian dishes, including those that use meat substitutes."},
                {"role": "user", "content": prompt}
            ]
        )
        
        # Try to parse the response as JSON
        try:
            result = response.choices[0].message.content.strip()
            
            # If the response indicates no menu items, return empty array
            if "doesn't seem to contain any identifiable restaurant dish names" in result:
                print("No menu items found in text")
                return "[]"
            
            # Find the JSON array in the response if there's additional text
            json_start = result.find('[')
            json_end = result.rfind(']') + 1
            if json_start >= 0 and json_end > json_start:
                result = result[json_start:json_end]
            else:
                print(f"Error: No JSON array found in response: {result}")
                return "[]"
            
            # Clean the JSON string
            result = result.replace('"', '"').replace('"', '"')  # Replace curly quotes
            result = result.replace(''', "'").replace(''', "'")  # Replace curly apostrophes
            result = result.replace('\u2019', "'")  # Replace Unicode apostrophe
            result = result.replace('\u2018', "'")  # Replace Unicode single quote
            result = result.replace('\u201c', '"')  # Replace Unicode double quote
            result = result.replace('\u201d', '"')  # Replace Unicode double quote
            
            # Remove or replace problematic control characters
            result = ''.join(char if ord(char) >= 32 or char in '\n\r\t' else ' ' for char in result)
            
            # Additional cleaning for specific issues
            result = re.sub(r'(?<=\d),(?=\d)', '', result)  # Remove commas between numbers
            result = re.sub(r'\s+', ' ', result)  # Normalize whitespace
            result = result.replace('\\', '')  # Remove backslashes
            
            # Validate JSON structure
            items = json.loads(result)
            if not isinstance(items, list):
                raise ValueError("Response is not a JSON array")
            
            # Validate each item and check for vegetarian markers
            for item in items:
                if not isinstance(item, dict):
                    raise ValueError("Array contains non-object items")
                if not all(k in item for k in ['item', 'category', 'is_vegetarian']):
                    raise ValueError("Items missing required fields")
                
                # Override classification if item has vegetarian marker
                if has_vegetarian_marker(item['item']):
                    item['is_vegetarian'] = True
                    print(f"Found vegetarian marker in: {item['item']}")
            
            return json.dumps(items)
        except json.JSONDecodeError as e:
            print(f"Error: Could not parse response as JSON: {e}")
            print("Raw response:", response.choices[0].message.content)
            return "[]"
        except ValueError as e:
            print(f"Error: Invalid response structure: {e}")
            return "[]"
            
    except Exception as e:
        print(f"Error classifying menu items: {e}")
        return "[]"

def process_classification_results(classification_text):
    try:
        if not classification_text or classification_text.strip() == "[]":
            return 0, 0
            
        items = json.loads(classification_text)
        if not items or not isinstance(items, list):
            return 0, 0
            
        veg_count = 0
        total_count = 0
        
        for item in items:
            if not isinstance(item, dict):
                continue
                
            total_count += 1
            is_vegetarian = item.get('is_vegetarian', False)
            if isinstance(is_vegetarian, str):
                is_vegetarian = is_vegetarian.lower() == 'true'
                
            if is_vegetarian:
                veg_count += 1
        
        return veg_count, total_count
        
    except json.JSONDecodeError as e:
        print(f"Error: Could not parse classification results as JSON: {e}")
        return 0, 0
    except Exception as e:
        print(f"Error processing classification results: {e}")
        return 0, 0

def save_menu_items_to_csv(items_data, output_file='menu_items.csv'):
    """Save individual menu items to a CSV file, appending if file exists."""
    try:
        new_df = pd.DataFrame(items_data)
        
        # Try to read existing file
        try:
            existing_df = pd.read_csv(output_file)
            # Append new data
            combined_df = pd.concat([existing_df, new_df], ignore_index=True)
            # Remove duplicates based on restaurant, menu_file, and item columns
            combined_df = combined_df.drop_duplicates(subset=['restaurant', 'menu_file', 'item'])
        except FileNotFoundError:
            combined_df = new_df
        
        combined_df.to_csv(output_file, index=False)
        print(f"\nAppended menu items to {output_file}")
    except Exception as e:
        print(f"Error saving menu items to CSV: {e}")

def save_restaurant_stats_to_csv(restaurant_stats, output_file='restaurant_stats.csv'):
    """Save restaurant statistics to a CSV file, updating existing entries if present."""
    try:
        # Convert restaurant stats to a list of dictionaries
        stats_list = []
        for restaurant, stats in restaurant_stats.items():
            stats_dict = {
                'restaurant': restaurant,
                'veg_items': stats['veg_items'],
                'total_items': stats['total_items'],
                'percentage': stats['percentage']
            }
            stats_list.append(stats_dict)
        
        new_df = pd.DataFrame(stats_list)
        
        # Try to read existing file
        try:
            existing_df = pd.read_csv(output_file)
            # Remove existing entries for the restaurants we're updating
            existing_df = existing_df[~existing_df['restaurant'].isin(new_df['restaurant'])]
            # Append new data
            combined_df = pd.concat([existing_df, new_df], ignore_index=True)
        except FileNotFoundError:
            combined_df = new_df
        
        # Sort by percentage descending
        combined_df = combined_df.sort_values('percentage', ascending=False)
        
        combined_df.to_csv(output_file, index=False)
        print(f"\nUpdated restaurant statistics in {output_file}")
    except Exception as e:
        print(f"Error saving restaurant stats to CSV: {e}")

def get_processed_restaurants(stats_file='restaurant_stats.csv'):
    """Get list of restaurants that have already been processed."""
    try:
        df = pd.read_csv(stats_file)
        return set(df['restaurant'].values)
    except FileNotFoundError:
        return set()

def save_misclassified_items_to_csv(items_data, output_file='misclassified_items.csv'):
    """Save misclassified items to a CSV file for model fine-tuning."""
    try:
        # Add columns for manual review
        for item in items_data:
            item['needs_review'] = True
            item['corrected'] = False
            item['manual_notes'] = ''
            # Ensure we have both original and corrected classifications
            if 'original_classification' not in item:
                item['original_classification'] = item.get('is_vegetarian', False)
            if 'correct_classification' not in item:
                item['correct_classification'] = None  # To be filled in during review
        
        new_df = pd.DataFrame(items_data)
        
        # Reorder columns for better readability
        columns_order = [
            'restaurant', 'menu_file', 'item', 'category',
            'original_classification', 'correct_classification',
            'needs_review', 'corrected', 'reason', 'manual_notes'
        ]
        new_df = new_df.reindex(columns=columns_order)
        
        # Try to read existing file
        try:
            existing_df = pd.read_csv(output_file)
            # Keep manual corrections from existing file
            existing_df = existing_df[existing_df['corrected'] == True]
            # Append new data
            combined_df = pd.concat([existing_df, new_df], ignore_index=True)
            # Remove duplicates based on restaurant, menu_file, and item
            combined_df = combined_df.drop_duplicates(subset=['restaurant', 'menu_file', 'item'])
        except FileNotFoundError:
            combined_df = new_df
        
        combined_df.to_csv(output_file, index=False)
        print(f"\nAppended misclassified items to {output_file}")
        print(f"You can now review and label the items in {output_file}")
        print("Set 'corrected' to True and fill in 'correct_classification' for items you've reviewed")
    except Exception as e:
        print(f"Error saving misclassified items to CSV: {e}")

def update_misclassified_labels(csv_file='misclassified_items.csv'):
    """Update the misclassified items CSV with manual corrections."""
    try:
        df = pd.read_csv(csv_file)
        # Count items needing review
        needs_review = df['needs_review'].sum()
        corrected = df['corrected'].sum()
        print(f"\nMisclassified items status:")
        print(f"- Total items: {len(df)}")
        print(f"- Items needing review: {needs_review}")
        print(f"- Items corrected: {corrected}")
        return df
    except FileNotFoundError:
        print(f"No misclassified items file found at {csv_file}")
        return None

# Start with all known vegan/vegetarian restaurants
VEGAN_RESTAURANTS = {
    'gauthier', 'mallow', 'tofu vegan', 'loving hut archway', 
    'jam delish', 'we are vegan everything', 'temple of seitan',
    'tendrils', 'sagar soho', 'rasa', 'holy carrot', 'club mexicana',
    'itadakizen', 'the gate hammersmith', 'persepolis peckham', 'sakonis wembley',
    'bühler and co', 'aya & suki', 'flat earth pizza', 'naifs', 'oliveira kitchen'
}

def analyze_menus(root_folder, target_folders=None):
    if not os.path.exists(root_folder):
        print(f"Error: Directory {root_folder} does not exist")
        return
    
    # Get list of establishments to process
    establishments = os.listdir(root_folder)
    if target_folders:
        # Filter to only process specified folders
        establishments = [est for est in establishments if est in target_folders]
        if not establishments:
            print(f"Error: None of the specified folders {target_folders} were found in {root_folder}")
            return
    else:
        # Process all restaurants (except hidden files)
        establishments = [est for est in establishments 
                        if not est.startswith('.') and 
                        os.path.isdir(os.path.join(root_folder, est))]
        
        if not establishments:
            print("No restaurants found!")
            return
        else:
            print(f"Found {len(establishments)} restaurants to process:")
            for est in establishments:
                print(f"- {est}")
                if est.lower() in VEGAN_RESTAURANTS:
                    print(f"  (Vegan/Vegetarian restaurant)")
            print()
    
    restaurant_stats = {}
    all_menu_items = []
    misclassified_items = []  # New list for tracking misclassified items
    
    for establishment in establishments:
        if establishment.startswith('.'):  # Skip hidden files/folders
            continue
            
        establishment_path = os.path.join(root_folder, establishment)
        if not os.path.isdir(establishment_path):
            continue
            
        print(f"\nAnalyzing menus for {establishment}:")
        
        # Get all PDF files in the directory
        pdf_files = []
        for file in os.listdir(establishment_path):
            if file.lower().endswith('.pdf'):
                pdf_files.append(file)
        
        if not pdf_files:
            print(f"  No PDF menu files found for {establishment}")
            continue
        
        total_veg_items = 0
        total_items = 0
        
        for filename in pdf_files:
            pdf_path = os.path.join(establishment_path, filename)
            print(f"\nProcessing: {filename}")
            menu_text = extract_text_from_pdf(pdf_path)
            
            if menu_text:
                classification = classify_menu_items(menu_text)
                veg_count, total_count = process_classification_results(classification)
                
                # Store individual menu items and check for misclassifications
                try:
                    items = json.loads(classification)
                    for item in items:
                        item['restaurant'] = establishment
                        item['menu_file'] = filename
                        all_menu_items.append(item)
                        
                        # Check for potential misclassifications
                        is_misclassified = False
                        original_classification = item['is_vegetarian']
                        
                        # Check if this is a known vegan/vegetarian restaurant
                        if establishment.lower() in VEGAN_RESTAURANTS and not item['is_vegetarian']:
                            is_misclassified = True
                            item['correct_classification'] = True
                            item['reason'] = f"{establishment} is a fully vegan/vegetarian restaurant"
                        
                        # Check for vegetarian markers in items classified as non-vegetarian
                        elif not item['is_vegetarian'] and has_vegetarian_marker(item['item'], establishment):
                            is_misclassified = True
                            item['correct_classification'] = True
                            item['reason'] = "Has vegetarian/vegan marker or is a vegan substitute"
                            print(f"Found misclassified item with vegetarian marker or vegan substitute: {item['item']}")
                        
                        if is_misclassified:
                            print(f"Adding misclassified item: {item['item']} (Reason: {item['reason']})")
                            misclassified_item = item.copy()
                            misclassified_item['original_classification'] = original_classification
                            misclassified_items.append(misclassified_item)
                            
                except json.JSONDecodeError:
                    print(f"Error parsing menu items for {filename}")
                
                if total_count > 0:  # Only add if we found items
                    total_veg_items += veg_count
                    total_items += total_count
                    
                    print(f"File results:")
                    print(f"Raw count: {veg_count}/{total_count} items vegetarian")
                    print("-" * 50)
            else:
                print(f"  Could not extract text from {filename}")
        
        if total_items > 0:
            percentage = (total_veg_items / total_items) * 100
            
            restaurant_stats[establishment] = {
                'veg_items': total_veg_items,
                'total_items': total_items,
                'percentage': percentage
            }
            
            print(f"\nSummary for {establishment}:")
            print(f"Raw count: {total_veg_items}/{total_items} items vegetarian ({percentage:.2f}%)")
        else:
            print(f"\nNo valid items found for {establishment}")
    
    if restaurant_stats:
        # Print overall summary
        print("\n" + "="*50)
        print("RESTAURANT VEGETARIAN PERCENTAGES SUMMARY")
        print("="*50)
        for restaurant, stats in sorted(restaurant_stats.items(), key=lambda x: x[1]['percentage'], reverse=True):
            print(f"{restaurant}:")
            print(f"  {stats['percentage']:.2f}% vegetarian ({stats['veg_items']}/{stats['total_items']})")
        
        # Save results to CSV files
        save_menu_items_to_csv(all_menu_items)
        save_restaurant_stats_to_csv(restaurant_stats)
        if misclassified_items:
            save_misclassified_items_to_csv(misclassified_items)
            print(f"\nFound {len(misclassified_items)} potentially misclassified items")
    else:
        print("\nNo valid data found for any restaurant")

def main():
    # Get target folders from command line arguments
    # Remove the script name and any arguments starting with '-'
    target_folders = [arg for arg in sys.argv[1:] if not arg.startswith('-')]
    
    # Remove @ symbol from folder names if present
    target_folders = [folder.lstrip('@') for folder in target_folders]
    
    # Use the absolute path to RestaurantMenus folder
    root_folder = '/Users/zarathomas/Projects/ConciergeX_Database/ConciergeX_Database/LLM_Vegetarian/RestaurantMenus'
    
    if target_folders:
        print(f"Processing specific folders: {', '.join(target_folders)}")
        analyze_menus(root_folder, target_folders)
    else:
        print("No folders specified, processing all folders")
        analyze_menus(root_folder)

if __name__ == "__main__":
    main()
