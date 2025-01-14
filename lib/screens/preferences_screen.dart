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
    'Business Meals',
    'Birthdays',
    'Date Nights',
    'Pre Theatre',
    'Cheap Eat',
    'Fine Dining',
    'Family Friendly',
    'Solo',
    'Bar',
    'Casual Dinner',
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
  List<String> _locationPreferences = [];
  List<String> _otherRequirements = [];
  List<String> _otherRestaurantPreferences = [];
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
      _locationPreferences = List<String>.from(widget.initialPreferences['location_preferences'] ?? []);
      _excludedCuisines = List<String>.from(widget.initialPreferences['excluded_cuisines'] ?? []);
      
      // Separate other requirements and preferences
      _otherRequirements = _selectedDietaryRequirements
          .where((req) => !_availableDietaryRequirements.contains(req))
          .toList();
      _selectedDietaryRequirements = _selectedDietaryRequirements
          .where((req) => _availableDietaryRequirements.contains(req))
          .toList();

      _otherRestaurantPreferences = _selectedRestaurantPreferences
          .where((pref) => !_availableRestaurantPreferences.contains(pref))
          .toList();
      _selectedRestaurantPreferences = _selectedRestaurantPreferences
          .where((pref) => _availableRestaurantPreferences.contains(pref))
          .toList();
          
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final preferences = {
        'dietary_requirements': [
          ..._selectedDietaryRequirements,
          ..._otherRequirements,
        ],
        'restaurant_preferences': [
          ..._selectedRestaurantPreferences,
          ..._otherRestaurantPreferences,
        ],
        'location_preferences': _locationPreferences,
        'excluded_cuisines': _excludedCuisines,
      };

      if (widget.isUserPreferences) {
        await _supabase.from('profiles').update(preferences).eq('id', _supabase.auth.currentUser!.id);
      }

      if (!mounted) return;

      // Call the callback with the preferences
      widget.onPreferencesSaved(preferences);
      
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      if (mounted) {
        setState(() => _error = 'Error saving preferences: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addLocationPreference() async {
    final location = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Location'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter location (e.g., Soho, Mayfair)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final textField = context.findRenderObject() as RenderBox;
              final text = (textField as dynamic).child?.child?.controller?.text;
              Navigator.pop(context, text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (location != null && location.isNotEmpty && mounted) {
      setState(() {
        _locationPreferences.add(location);
      });
    }
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
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: const Text(
                      'Location Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Preferred Areas',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _addLocationPreference,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _locationPreferences.map((location) {
                                return Chip(
                                  label: Text(location),
                                  onDeleted: () {
                                    setState(() {
                                      _locationPreferences.remove(location);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}