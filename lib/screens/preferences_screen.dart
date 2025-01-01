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
  List<String> _availableCuisines = [];
  Map<String, bool> _dietaryRequirements = {};
  Map<String, bool> _restaurantPreferences = {};
  final List<String> _excludedCuisines = [];

  // Add expansion state
  bool _isDietaryExpanded = false;
  bool _isRestaurantExpanded = false;
  bool _isCuisineExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadCuisineTypes();
    _loadDietaryRequirements();
    _loadRestaurantPreferences();
    _excludedCuisines.addAll(
      List<String>.from(widget.initialPreferences['excluded_cuisines'] ?? [])
    );
  }

  Future<void> _loadRestaurantPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all feature columns from restaurants_features table
      final features = await _supabase
          .rpc('get_distinct_restaurant_features');

      print('Features from DB: $features'); // Debug log

      // Get user's preferences
      final userPrefs = await _supabase
          .from('user_restaurant_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      setState(() {
        // Initialize preferences with features from database
        _restaurantPreferences = Map.fromEntries(
          (features as List).map<MapEntry<String, bool>>((feature) => 
            MapEntry(feature['feature_name'] as String, feature['feature_value'] as bool)
          )
        );

        // Update with user's selected preferences if they exist
        if (userPrefs != null) {
          for (var entry in (userPrefs as Map<String, dynamic>).entries) {
            if (entry.key != 'user_id' && 
                entry.key != 'created_at' && 
                entry.key != 'updated_at' &&
                _restaurantPreferences.containsKey(entry.key)) {
              _restaurantPreferences[entry.key] = entry.value as bool;
            }
          }
        }
      });

      print('Loaded ${_restaurantPreferences.length} restaurant preferences from database');
      print('Preferences: $_restaurantPreferences'); // Debug log
    } catch (e) {
      print('Error loading restaurant preferences: $e');
      print('Error details: ${e.toString()}');
    }
  }

  Future<void> _saveRestaurantPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('user_restaurant_preferences')
          .upsert({
            'user_id': userId,
            ..._restaurantPreferences,
            'updated_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error saving restaurant preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving restaurant preferences: $e')),
      );
    }
  }

  Future<void> _loadDietaryRequirements() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get the user's current dietary requirements
      final response = await _supabase
          .from('user_dietary_requirements')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      setState(() {
        _dietaryRequirements = {
          'no_beef': response?['no_beef'] ?? false,
          'no_pork': response?['no_pork'] ?? false,
          'vegetarian': response?['vegetarian'] ?? false,
          'vegan': response?['vegan'] ?? false,
          'halal': response?['halal'] ?? false,
          'kosher': response?['kosher'] ?? false,
          'gluten_free': response?['gluten_free'] ?? false,
          'dairy_free': response?['dairy_free'] ?? false,
          'nut_allergy': response?['nut_allergy'] ?? false,
          'shellfish_allergy': response?['shellfish_allergy'] ?? false,
        };
      });
    } catch (e) {
      print('Error loading dietary requirements: $e');
    }
  }

  Future<void> _saveDietaryRequirements() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('user_dietary_requirements')
          .upsert({
            'user_id': userId,
            ..._dietaryRequirements,
            'updated_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error saving dietary requirements: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving dietary requirements: $e')),
      );
    }
  }

  Future<void> _loadCuisineTypes() async {
    setState(() => _loading = true);
    try {
      final cuisines = await CuisineTypes.all;
      setState(() {
        _availableCuisines = cuisines;
        _loading = false;
      });
    } catch (e) {
      print('Error loading cuisine types: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isUserPreferences ? 'Your Preferences' : 'Member Preferences'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Dietary Requirements Section
                  ExpansionTile(
                    initiallyExpanded: _isDietaryExpanded,
                    title: const Text(
                      'Dietary Requirements',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() => _isDietaryExpanded = expanded);
                    },
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _dietaryRequirements.entries.map((entry) {
                          return FilterChip(
                            label: Text(entry.key.replaceAll('_', ' ').toTitleCase()),
                            selected: entry.value,
                            onSelected: (selected) {
                              setState(() {
                                _dietaryRequirements[entry.key] = selected;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // Restaurant Preferences Section
                  ExpansionTile(
                    initiallyExpanded: _isRestaurantExpanded,
                    title: const Text(
                      'Restaurant Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() => _isRestaurantExpanded = expanded);
                    },
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _restaurantPreferences.entries.map((entry) {
                          return FilterChip(
                            label: Text(entry.key.replaceAll('_', ' ').toTitleCase()),
                            selected: entry.value,
                            onSelected: (selected) {
                              setState(() {
                                _restaurantPreferences[entry.key] = selected;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // Excluded Cuisines Section
                  ExpansionTile(
                    initiallyExpanded: _isCuisineExpanded,
                    title: const Text(
                      'Excluded Cuisines',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() => _isCuisineExpanded = expanded);
                    },
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableCuisines.map((cuisine) {
                          final isSelected = _excludedCuisines.contains(cuisine);
                          return FilterChip(
                            label: Text(cuisine),
                            selected: isSelected,
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
                    ],
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: () async {
              await _saveDietaryRequirements();
              await _saveRestaurantPreferences();
              widget.onPreferencesSaved({
                'excluded_cuisines': _excludedCuisines,
              });
            },
            child: const Text('Save Preferences'),
          ),
        ),
      ),
    );
  }
}