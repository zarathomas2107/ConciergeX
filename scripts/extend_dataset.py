import pandas as pd
import csv

new_examples = [
    {
        "Request": "Looking for a Lebanese restaurant near Royal Court Theatre for pre-show dinner, good for business meals",
        "Response": """{
            "cuisine_type": "Lebanese",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:00:00",
            "end_time": "18:30:00",
            "requested_seats": 4,
            "venue_type": "theatre",
            "venue_name": "Royal Court Theatre",
            "show_time": "19:00:00",
            "features": ["Business_Meals", "Pre_Theatre", "Dinner"]
        }"""
    },
    {
        "Request": "Chinese restaurant for family dinner near Vue Cinema, needs to be kid-friendly",
        "Response": """{
            "cuisine_type": "Chinese",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:30:00",
            "end_time": "19:00:00",
            "requested_seats": 5,
            "venue_type": "cinema",
            "venue_name": "Vue Cinema",
            "show_time": "19:30:00",
            "features": ["kids", "Casual_Dinner", "Dinner"]
        }"""
    },
    {
        "Request": "American diner style restaurant near BFI IMAX for cheap pre-movie meal",
        "Response": """{
            "cuisine_type": "American",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:00:00",
            "end_time": "18:30:00",
            "requested_seats": 2,
            "venue_type": "cinema",
            "venue_name": "BFI IMAX",
            "show_time": "19:00:00",
            "features": ["Cheap_Eat", "Casual_Dinner", "Pre_Theatre"]
        }"""
    },
    {
        "Request": "Seafood restaurant for date night near Savoy Theatre, fine dining preferred",
        "Response": """{
            "cuisine_type": "Seafood",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:30:00",
            "end_time": "19:00:00",
            "requested_seats": 2,
            "venue_type": "theatre",
            "venue_name": "Savoy Theatre",
            "show_time": "19:30:00",
            "features": ["Fine_Dining", "Date Nights", "Pre_Theatre"]
        }"""
    },
    {
        "Request": "Spanish tapas place near Curzon Soho for solo dining before late movie",
        "Response": """{
            "cuisine_type": "Spanish",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "19:00:00",
            "end_time": "20:30:00",
            "requested_seats": 1,
            "venue_type": "cinema",
            "venue_name": "Curzon Soho",
            "show_time": "21:00:00",
            "features": ["solo", "Casual_Dinner", "Pre_Theatre"]
        }"""
    },
    {
        "Request": "Vietnamese restaurant near Old Vic, needs to be dog-friendly and casual",
        "Response": """{
            "cuisine_type": "Vietnamese",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:00:00",
            "end_time": "18:30:00",
            "requested_seats": 3,
            "venue_type": "theatre",
            "venue_name": "Old Vic",
            "show_time": "19:00:00",
            "features": ["Dog_Friendly", "Casual_Dinner", "Pre_Theatre"]
        }"""
    },
    {
        "Request": "Israeli brunch spot near National Theatre before matinee show",
        "Response": """{
            "cuisine_type": "Israeli",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "11:00:00",
            "end_time": "12:30:00",
            "requested_seats": 4,
            "venue_type": "theatre",
            "venue_name": "National Theatre",
            "show_time": "14:00:00",
            "features": ["Brunch", "Pre_Theatre"]
        }"""
    },
    {
        "Request": "Cuban restaurant for birthday celebration near Prince Charles Cinema",
        "Response": """{
            "cuisine_type": "Cuban",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:00:00",
            "end_time": "18:30:00",
            "requested_seats": 8,
            "venue_type": "cinema",
            "venue_name": "Prince Charles Cinema",
            "show_time": "19:00:00",
            "features": ["Birthdays", "Pre_Theatre", "Dinner"]
        }"""
    },
    {
        "Request": "Mexican restaurant near Barbican Theatre, needs to be good for business dinner",
        "Response": """{
            "cuisine_type": "Mexican",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:30:00",
            "end_time": "19:00:00",
            "requested_seats": 6,
            "venue_type": "theatre",
            "venue_name": "Barbican Theatre",
            "show_time": "19:30:00",
            "features": ["Business_Meals", "Pre_Theatre", "Dinner"]
        }"""
    },
    {
        "Request": "Thai restaurant for cheap lunch near Picturehouse Central before afternoon show",
        "Response": """{
            "cuisine_type": "Thai",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "12:00:00",
            "end_time": "13:30:00",
            "requested_seats": 2,
            "venue_type": "cinema",
            "venue_name": "Picturehouse Central",
            "show_time": "14:00:00",
            "features": ["Cheap_Eat", "Lunch", "Pre_Theatre"]
        }"""
    },
    {
        "Request": "Steakhouse near Apollo Theatre for anniversary dinner before show",
        "Response": """{
            "cuisine_type": "Steakhouse",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:00:00",
            "end_time": "18:30:00",
            "requested_seats": 2,
            "venue_type": "theatre",
            "venue_name": "Apollo Theatre",
            "show_time": "19:00:00",
            "features": ["Fine_Dining", "Date Nights", "Pre_Theatre"]
        }"""
    },
    {
        "Request": "Traditional British pub near Royal Opera House for pre-show dinner",
        "Response": """{
            "cuisine_type": "British",
            "restaurant_name": null,
            "start_date": "2025-01-01",
            "end_date": "2025-01-01",
            "start_time": "17:30:00",
            "end_time": "19:00:00",
            "requested_seats": 4,
            "venue_type": "theatre",
            "venue_name": "Royal Opera House",
            "show_time": "19:30:00",
            "features": ["Casual_Dinner", "Pre_Theatre", "Dinner"]
        }"""
    }
]

# Read existing CSV
df = pd.read_csv('/Users/zara.thomas/PycharmProjects/NomNomNow/FlutterFlow/flutterflow/ConciergeX/PythonPrep/extended_finetuning_examples.csv')

# Add new examples
new_df = pd.DataFrame(new_examples)
df = pd.concat([df, new_df], ignore_index=True)

# Save back to CSV
df.to_csv('/Users/zara.thomas/PycharmProjects/NomNomNow/FlutterFlow/flutterflow/ConciergeX/PythonPrep/extended_finetuning_examples.csv', index=False) 