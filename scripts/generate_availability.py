import pandas as pd
from datetime import datetime, timedelta
import uuid

def generate_availability_rows():
    # Read both CSVs
    availability_df = pd.read_csv('PythonPrep/restaurants_availability_rows.csv')
    restaurants_df = pd.read_csv('PythonPrep/restaurants_rows (3).csv')

    # Get existing restaurant IDs from availability
    existing_ids = availability_df['RestaurantID'].unique()

    # Filter for new restaurants
    new_restaurants = restaurants_df[~restaurants_df['RestaurantID'].isin(existing_ids)]

    # Define dates and time slots
    dates = ['2025-01-01', '2025-01-02']
    time_slots = ['18:00:00', '18:30:00', '19:00:00', '19:30:00', '20:00:00']
    
    # Create new rows
    new_rows = []
    current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S+00')

    for _, restaurant in new_restaurants.iterrows():
        for date in dates:
            for time_slot in time_slots:
                new_rows.append({
                    'UUID': str(uuid.uuid4()),
                    'RestaurantID': restaurant['RestaurantID'],
                    'Name': restaurant['Name'],
                    'CuisineType': restaurant['CuisineType'],
                    'date': date,
                    'time_slot': time_slot,
                    'total_capacity': 30,
                    'booked_seats': 0,
                    'is_available': True,
                    'created_at': current_time,
                    'updated_at': current_time
                })

    # Create DataFrame with only new rows
    new_availability_df = pd.DataFrame(new_rows)
    
    # Save only the new rows to CSV
    output_file = 'PythonPrep/new_restaurants_availability.csv'
    new_availability_df.to_csv(output_file, index=False)
    
    print(f"Generated {len(new_rows)} availability rows for {len(new_restaurants)} new restaurants")
    print(f"Saved to {output_file}")

if __name__ == "__main__":
    generate_availability_rows() 