import re
import os
import sys
import pandas as pd
from PyPDF2 import PdfReader
import pdfplumber
import logging
import pytesseract
import easyocr
from pdf2image import convert_from_path
import tempfile

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def extract_text_with_ocr(file_path, use_easyocr=False):
    """Extract text from PDF using OCR."""
    try:
        # Convert PDF to images
        logger.info("Converting PDF to images...")
        images = convert_from_path(file_path)
        text = ""
        
        if use_easyocr:
            # Initialize EasyOCR
            logger.info("Initializing EasyOCR...")
            reader = easyocr.Reader(['en'])
            
            # Process each page
            for i, image in enumerate(images, 1):
                logger.info(f"Processing page {i} with EasyOCR...")
                # Get text from image
                results = reader.readtext(numpy.array(image))
                # Extract text from results
                page_text = ' '.join([result[1] for result in results])
                text += page_text + "\n"
        else:
            # Use Tesseract
            for i, image in enumerate(images, 1):
                logger.info(f"Processing page {i} with Tesseract...")
                # Get text from image
                page_text = pytesseract.image_to_string(image)
                text += page_text + "\n"
        
        return text
    except Exception as e:
        logger.error(f"OCR failed: {e}")
        return ""

def extract_text(file_path):
    """Extract text from PDF using multiple methods in order of preference."""
    text = ""
    
    # Method 1: Try pdfplumber first (best for preserving layout)
    logger.info("Attempting text extraction with pdfplumber...")
    try:
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                # Try different extraction methods
                extraction_methods = [
                    lambda: page.extract_text(layout=True),
                    lambda: page.extract_text(layout=False),
                    lambda: page.extract_text(x_tolerance=3, y_tolerance=3),
                    lambda: page.extract_text(x_tolerance=5, y_tolerance=5),
                    lambda: ' '.join(word['text'] for word in page.extract_words())
                ]
                
                for method in extraction_methods:
                    try:
                        page_text = method()
                        if page_text and len(page_text.strip()) > 0:
                            text += page_text + "\n"
                            break
                    except Exception as e:
                        logger.debug(f"pdfplumber extraction method failed: {e}")
                        continue
            
            if text.strip():
                logger.info("Successfully extracted text with pdfplumber")
                return text
    except Exception as e:
        logger.warning(f"pdfplumber failed: {e}")

    # Method 2: Try PyPDF2 (good for simple PDFs)
    logger.info("Attempting text extraction with PyPDF2...")
    try:
        reader = PdfReader(file_path)
        for page in reader.pages:
            try:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
            except Exception as e:
                logger.warning(f"Failed to extract text from page: {e}")
                continue
        if text.strip():
            logger.info("Successfully extracted text with PyPDF2")
            return text
    except Exception as e:
        logger.warning(f"PyPDF2 failed: {e}")

    # Method 3: Try Tesseract OCR (for image-based PDFs)
    if not text.strip():
        logger.info("Regular extraction failed, attempting Tesseract OCR...")
        try:
            text = extract_text_with_ocr(file_path, use_easyocr=False)
            if text.strip():
                logger.info("Successfully extracted text with Tesseract OCR")
                return text
        except Exception as e:
            logger.warning(f"Tesseract OCR failed: {e}")
        
        # Method 4: Try EasyOCR (alternative OCR method)
        if not text.strip():
            logger.info("Tesseract OCR failed, attempting EasyOCR...")
            try:
                text = extract_text_with_ocr(file_path, use_easyocr=True)
                if text.strip():
                    logger.info("Successfully extracted text with EasyOCR")
                    return text
            except Exception as e:
                logger.warning(f"EasyOCR failed: {e}")

    if not text.strip():
        raise ValueError("Failed to extract text from PDF using all available methods")
    
    return text

# Function to clean text
def clean_text(text):
    # Remove URLs and email addresses
    text = re.sub(r'http\S+|www\.\S+|\S+@\S+', '', text)
    
    # Remove common menu headers and footers
    text = re.sub(r'(?i)(wifi|instagram|facebook|twitter|allergen|service charge|vat|please note|all prices|menu|opening hours|book now|available|weekdays|weekends).*?(\n|$)', '', text)
    
    # Remove standalone prices, page numbers, and dates
    text = re.sub(r'^\s*£?\d+(?:\.\d{2})?(?:/\d+g)?\s*$', '', text, flags=re.MULTILINE)
    text = re.sub(r'^\s*Page \d+\s*$', '', text, flags=re.MULTILINE)
    text = re.sub(r'^\s*\d+\s*$', '', text, flags=re.MULTILINE)
    text = re.sub(r'\d{1,2}/\d{1,2}/\d{2,4}', '', text)  # Remove dates like 12/01/2025
    text = re.sub(r'\d{1,2}:\d{2}(?:\s*[AaPp][Mm])?', '', text)  # Remove times
    
    # Remove common menu annotations
    text = re.sub(r'\([^)]*\)', ' ', text)  # Remove parentheses and contents
    text = re.sub(r'\[.*?\]', ' ', text)    # Remove square brackets and contents
    text = re.sub(r'\{.*?\}', ' ', text)    # Remove curly braces and contents
    
    # Remove date patterns
    text = re.sub(r'\d{1,2}(?:st|nd|rd|th)?\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{4}', '', text)
    
    # Remove multiple spaces and clean up
    text = re.sub(r'\s+', ' ', text)
    text = text.strip()
    
    return text

# Function to extract price and description
def extract_price_and_description(line):
    # Match prices with optional decimals and units
    price_pattern = r'(?:^|\s)(?:£|\$|€)\d+(?:\.\d{2})?(?:/\d+g)?(?:\s|$)'
    description_pattern = r'^(.*?)(?:(?:£|\$|€)\d+(?:\.\d{2})?(?:/\d+g)?)+\s*$'
    
    prices = re.findall(price_pattern, line)
    if not prices:
        # Try looking for numeric prices without currency symbol
        price_pattern = r'(?:^|\s)\d+(?:\.\d{2})?(?:\s|$)'
        prices = re.findall(price_pattern, line)
        if not prices:
            return None, None
    
    # Get the description (everything before the first price)
    match = re.match(description_pattern, line)
    if match:
        description = match.group(1).strip()
    else:
        description = line[:line.find(prices[0])].strip()
    
    # Get the last price (most likely the actual price)
    price = prices[-1].strip()
    if not price.startswith('£'):
        price = '£' + price
    
    # Clean up the description
    description = clean_text(description)
    
    # Skip if description is too short or just numbers
    if len(description) < 3 or description.isdigit():
        return None, None
        
    return description, price

# Function to split text into menu items
def split_into_menu_items(text):
    # Split on common patterns that indicate new items
    patterns = [
        r'(?m)^[A-Z][^£\n]*[£\$€]\d+',  # Capitalized text followed by price
        r'(?m)^[•\-]\s*[^£\n]*[£\$€]\d+',  # Bullet points followed by price
        r'(?m)^\d+\.\s*[^£\n]*[£\$€]\d+',  # Numbers followed by price
        r'(?m)^[A-Z][A-Z\s]+(?:\n|$)',  # All caps section headers
        r'(?m)^[A-Za-z][^£\n]{3,}[£\$€]\d+',  # Any text followed by price (at least 3 chars)
        r'(?m)^[A-Za-z].{10,}(?:\n|$)',  # Long lines of text (likely descriptions)
        r'(?m)^[A-Za-z][^£\n]*\s+[£\$€]\d+',  # Any text ending with a price
        r'(?m)^[A-Za-z][^£\n]*\s*\d+\.?\d*\s*$'  # Any text ending with a number
    ]
    
    # First, try to split by clear price indicators
    items = []
    current_item = []
    lines = text.splitlines()
    
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue
            
        is_new_item = any(re.match(pattern, line) for pattern in patterns)
        has_price = any(c in line for c in '£$€') or re.search(r'\d+\.?\d*', line)
        is_short = len(line) < 10
        next_line_has_price = i < len(lines)-1 and any(c in lines[i+1] for c in '£$€')
        
        if is_new_item or (has_price and not current_item):
            if current_item:
                items.append(' '.join(current_item))
            current_item = [line]
        elif is_short and current_item:
            # If this line is short and the next line has a price,
            # treat this as part of the current item
            if next_line_has_price:
                items.append(' '.join(current_item))
                current_item = [line]
            else:
                current_item.append(line)
        else:
            current_item.append(line)
    
    if current_item:
        items.append(' '.join(current_item))
    
    # Post-process items
    processed_items = []
    for item in items:
        # Split items if they contain multiple prices
        price_matches = list(re.finditer(r'[£\$€]\d+(?:\.\d{2})?(?:/\d+g)?', item))
        if len(price_matches) > 1:
            last_end = 0
            for match in price_matches:
                # Find a reasonable split point before the price
                split_point = item.rfind(' ', last_end, match.start())
                if split_point > last_end:
                    sub_item = item[last_end:split_point].strip()
                    if sub_item:
                        processed_items.append(sub_item + ' ' + item[match.start():match.end()])
                last_end = match.end()
            # Add the remaining text if any
            if last_end < len(item):
                processed_items.append(item[last_end:].strip())
        else:
            processed_items.append(item)
    
    return processed_items

# Function to parse text into structured data
def parse_menu_text(text):
    # Clean the text first
    text = clean_text(text)
    
    # Try to split text into individual menu items
    items = split_into_menu_items(text)
    
    data = []
    for item in items:
        # Skip likely section headers
        if item.isupper() or len(item) < 5:
            continue
            
        # Try to find menu items with prices
        price_matches = list(re.finditer(r'(?:£|\$|€)\d+(?:\.\d{2})?(?:/\d+g)?|\b\d+(?:\.\d{2})?\b(?=\s|$)', item))
        
        if price_matches:
            # Handle multiple prices in the same line
            last_end = 0
            for match in price_matches:
                # Get the text before this price
                if last_end == 0:
                    description = item[:match.start()].strip()
                else:
                    description = item[last_end:match.start()].strip()
                
                price = match.group()
                if not price.startswith('£'):
                    # Convert numeric price to pounds
                    price = '£' + price
                
                # Clean up the description
                description = clean_text(description)
                
                # Skip if description is too short or just numbers
                if len(description) >= 3 and not description.isdigit():
                    # Skip if it looks like a header
                    if not all(word[0].isupper() for word in description.split()):
                        # Skip common non-menu items
                        if not re.search(r'(?i)(wifi|password|allergen|instagram|facebook|twitter)', description):
                            data.append((description, price))
                
                last_end = match.end()
        else:
            # Try alternative price formats
            description, price = extract_price_and_description(item)
            if description and price:
                data.append((description, price))
    
    # Post-process to combine similar items
    processed_data = []
    seen_descriptions = set()
    
    for description, price in data:
        # Create a normalized version for comparison
        normalized = re.sub(r'\s+', ' ', description.lower())
        
        # Skip if we've seen this item before
        if normalized in seen_descriptions:
            continue
            
        seen_descriptions.add(normalized)
        processed_data.append((description, price))
    
    return processed_data

# Function to process a PDF file into a DataFrame
def process_pdf(file_path, restaurant_name):
    logger.info(f"\nProcessing: {os.path.basename(file_path)}")
    text = extract_text(file_path)
    if not text.strip():
        raise ValueError("Failed to extract text from PDF.")
    
    # Try different parsing approaches
    parsed_data = []
    
    # Approach 1: Standard parsing
    parsed_data = parse_menu_text(text)
    
    # Approach 2: If no items found, try line-by-line parsing
    if not parsed_data:
        logger.info("No items found with primary parsing method, trying line-by-line parsing...")
        lines = text.splitlines()
        current_section = ""
        description_buffer = []
        
        for line in lines:
            line = clean_text(line)
            if not line:
                continue
            
            # Skip likely headers and footers
            if (line.isupper() or len(line) < 5 or 
                re.search(r'(?i)(all our dishes|not all ingredients|whilst we take|dedicated preparation|cross contamination|optional|allergen|dietary)', line)):
                continue
                
            # Look for price patterns
            price_match = re.search(r'(?:£|\$|€)\d+(?:\.\d{2})?(?:/\d+g)?|\b\d+(?:\.\d{2})?\b(?=\s|$)', line)
            if price_match:
                description = line[:price_match.start()].strip()
                price = price_match.group()
                if not price.startswith('£'):
                    price = '£' + price
                
                # If we have accumulated description, combine it
                if description_buffer:
                    full_description = ' '.join(description_buffer) + ' ' + description
                    description_buffer = []
                else:
                    full_description = description
                
                full_description = clean_text(full_description)
                if len(full_description) >= 3 and not full_description.isdigit():
                    parsed_data.append((full_description, price))
            elif len(line) > 10 and not line.isupper():
                # Accumulate description if line is substantial
                description_buffer.append(line)
    
    # Approach 3: If still no items found, try splitting by numbers
    if not parsed_data:
        logger.info("No items found with line-by-line parsing, trying number-based splitting...")
        # Look for patterns like "1. Item name £10" or "Item name 10"
        matches = re.finditer(r'(?:(?:\d+\.\s*)?([^£\d][^£]*?)(?:£|\$|€)?(\d+(?:\.\d{2})?))(?=\s|$)', text)
        for match in matches:
            description = clean_text(match.group(1))
            price = '£' + match.group(2)
            if len(description) >= 3 and not description.isdigit():
                parsed_data.append((description, price))
    
    df = pd.DataFrame(parsed_data, columns=["Dish Name and Description", "Price"])
    
    # Clean up the data
    df = df[df['Dish Name and Description'].str.len() > 3]  # Remove very short descriptions
    df = df[~df['Dish Name and Description'].str.match(r'^\d+$')]  # Remove numeric-only descriptions
    df = df[~df['Dish Name and Description'].str.contains(r'(?i)wifi|password|allergen|instagram|facebook|twitter|book now|all our dishes|not all ingredients|whilst we take|dedicated preparation|cross contamination|optional')]  # Remove non-menu items
    
    # Remove items that are just times or dates
    df = df[~df['Dish Name and Description'].str.match(r'^\s*\d{1,2}[/:]\d{1,2}')]
    
    # Remove items that are just section headers
    df = df[~df['Dish Name and Description'].str.match(r'^[A-Z\s]+$')]
    
    # Add restaurant and menu file information
    df['Restaurant'] = restaurant_name
    df['Menu File'] = os.path.basename(file_path)
    
    # Reorder columns
    df = df[['Restaurant', 'Menu File', 'Dish Name and Description', 'Price']]
    
    logger.info(f"\nExtracted {len(df)} items from {os.path.basename(file_path)}:")
    if not df.empty:
        logger.info("\n" + df.to_string(index=False))
    logger.info("-" * 50)
    
    return df

def process_restaurant_menus(root_folder, target_folders=None):
    """Process PDFs from specified restaurant folders."""
    if not os.path.exists(root_folder):
        logger.error(f"Error: Directory {root_folder} does not exist")
        return None

    all_menus_df = pd.DataFrame()

    # Get list of restaurants to process
    try:
        restaurants = [d for d in os.listdir(root_folder) 
                      if os.path.isdir(os.path.join(root_folder, d)) and not d.startswith('.')]
    except Exception as e:
        logger.error(f"Error listing directory {root_folder}: {e}")
        return None

    if target_folders:
        # Filter to only process specified folders
        restaurants = [rest for rest in restaurants if rest in target_folders]
        if not restaurants:
            logger.error(f"Error: None of the specified restaurants {target_folders} were found in {root_folder}")
            return None

    for restaurant in restaurants:
        restaurant_path = os.path.join(root_folder, restaurant)
        logger.info(f"\nAnalyzing menus for {restaurant}:")
        
        # Get all PDF files in the directory
        try:
            pdf_files = [f for f in os.listdir(restaurant_path) 
                        if f.lower().endswith('.pdf')]
        except Exception as e:
            logger.error(f"Error listing PDFs in {restaurant_path}: {e}")
            continue
        
        if not pdf_files:
            logger.warning(f"  No PDF menu files found for {restaurant}")
            continue
        
        # Process each PDF
        for pdf_file in pdf_files:
            pdf_path = os.path.join(restaurant_path, pdf_file)
            try:
                df = process_pdf(pdf_path, restaurant)
                if df is not None and not df.empty:
                    # Append to the combined DataFrame
                    all_menus_df = pd.concat([all_menus_df, df], ignore_index=True)
            except Exception as e:
                logger.error(f"Failed to process {pdf_path}: {e}")

    return all_menus_df

def main():
    # Get target folders from command line arguments
    target_folders = [arg for arg in sys.argv[1:] if not arg.startswith('-')]
    
    # Remove @ symbol from folder names if present
    target_folders = [folder.lstrip('@') for folder in target_folders]
    
    # Use the current directory's RestaurantMenus folder
    root_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'RestaurantMenus')
    
    if target_folders:
        logger.info(f"Processing specific restaurants: {', '.join(target_folders)}")
        all_menus_df = process_restaurant_menus(root_folder, target_folders)
    else:
        logger.info("No restaurants specified, processing all restaurants")
        all_menus_df = process_restaurant_menus(root_folder)
    
    if all_menus_df is not None and not all_menus_df.empty:
        # Save to CSV
        output_file = 'extracted_menus.csv'
        all_menus_df.to_csv(output_file, index=False)
        logger.info(f"\nSaved {len(all_menus_df)} menu items to {output_file}")
    else:
        logger.error("No menu items were extracted.")

if __name__ == "__main__":
    main()
