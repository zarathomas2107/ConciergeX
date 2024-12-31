import pandas as pd

# Read the CSV
df = pd.read_csv('PythonPrep/restaurants_availability_rows_updated.csv')

# Check for duplicate UUIDs
duplicate_uuids = df[df.duplicated(subset=['UUID'], keep=False)]

if len(duplicate_uuids) > 0:
    print(f"Found {len(duplicate_uuids)} rows with duplicate UUIDs:")
    print(duplicate_uuids[['UUID', 'RestaurantID', 'Name', 'date', 'time_slot']].sort_values('UUID'))
else:
    print("No duplicate UUIDs found")

# Also check total number of unique UUIDs vs total rows
total_rows = len(df)
unique_uuids = len(df['UUID'].unique())
print(f"\nTotal rows: {total_rows}")
print(f"Unique UUIDs: {unique_uuids}") 