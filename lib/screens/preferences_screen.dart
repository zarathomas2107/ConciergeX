import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/string_extensions.dart';
import '../widgets/multi_select_location_dialog.dart';
import '../constants/cuisine_types.dart';

class PreferencesScreen extends StatefulWidget {
  final bool isUserPreferences;
  final Map<String, dynamic> initialPreferences;
  final Function(Map<String, dynamic>) onPreferencesSaved;

  const PreferencesScreen({
    Key? key,
    required this.isUserPreferences,
    required this.initialPreferences,
    required this.onPreferencesSaved,
  }) : super(key: key);

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;
  String? _error;
  
  // Define available options
  final List<String> _availableDietaryRequirements = [
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Halal',
    'Kosher',
    'Gluten Free',
    'Dairy Free',
    'Nut Free',
    'Shellfish_allergy',
    'No Beef',
    'No Pork',
  ];

  final List<String> _availableRestaurantPreferences = [
    'Dog_Friendly',
    'Business_Meals',
    'Birthdays',
    'Date_Nights',
    'Pre_Theatre',
    'Cheap_Eat',
    'Fine_Dining',
    'Family_Friendly',
    'Solo',
    'Bar',
    'Casual_Dinner',
    'Brunch',
    'Breakfast',
    'Lunch',
    'Dinner',
  ];

  final List<String> _availableCuisines = [
    'Italian',
    'Japanese',
    'Chinese',
    'Indian',
    'French',
    'Thai',
    'Mexican',
    'Mediterranean',
    'British',
    'American',
    'Korean',
    'Vietnamese',
    'Spanish',
    'Greek',
    'Turkish',
  ];

  List<String> _excludedCuisines = [];
  List<String> _selectedDietaryRequirements = [];
  List<String> _selectedRestaurantPreferences = [];
  bool _isDietaryExpanded = false;
  bool _isRestaurantExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _loading = true);

    try {
      // Initialize from initial preferences
      _selectedDietaryRequirements = List<String>.from(widget.initialPreferences['dietary_requirements'] ?? []);
      _selectedRestaurantPreferences = List<String>.from(widget.initialPreferences['restaurant_preferences'] ?? []);
      _excludedCuisines = List<String>.from(widget.initialPreferences['excluded_cuisines'] ?? []);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _savePreferences() {
    final preferences = {
      'dietary_requirements': _selectedDietaryRequirements,
      'restaurant_preferences': _selectedRestaurantPreferences,
      'excluded_cuisines': _excludedCuisines,
    };

    widget.onPreferencesSaved(preferences);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.isUserPreferences ? 'Your Preferences' : 'Member Preferences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePreferences,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: _isDietaryExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _isDietaryExpanded = expanded);
                    },
                    title: const Text(
                      'Dietary Requirements',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableDietaryRequirements.map((requirement) {
                            return FilterChip(
                              label: Text(requirement.replaceAll('_', ' ').toTitleCase()),
                              selected: _selectedDietaryRequirements.contains(requirement),
                              selectedColor: Colors.black.withOpacity(0.15),
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedDietaryRequirements.add(requirement);
                                  } else {
                                    _selectedDietaryRequirements.remove(requirement);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: _isRestaurantExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _isRestaurantExpanded = expanded);
                    },
                    title: const Text(
                      'Restaurant Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableRestaurantPreferences.map((preference) {
                            return FilterChip(
                              label: Text(preference.replaceAll('_', ' ').toTitleCase()),
                              selected: _selectedRestaurantPreferences.contains(preference),
                              selectedColor: Colors.black.withOpacity(0.15),
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedRestaurantPreferences.add(preference);
                                  } else {
                                    _selectedRestaurantPreferences.remove(preference);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: const Text(
                      'Excluded Cuisines',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableCuisines.map((cuisine) {
                            return FilterChip(
                              label: Text(cuisine.toTitleCase()),
                              selected: _excludedCuisines.contains(cuisine),
                              selectedColor: Colors.black.withOpacity(0.15),
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _excludedCuisines.add(cuisine);
                                  } else {
                                    _excludedCuisines.remove(cuisine);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}