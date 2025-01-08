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
  List<String> _availableCuisines = [];
  Map<String, bool> _dietaryRequirements = {};
  List<String> _excludedCuisines = [];
  List<String> _restaurantFeatures = [];
  List<String> _selectedDietaryRequirements = [];
  List<String> _selectedFeatures = [];

  // Add expansion state
  bool _isDietaryExpanded = false;
  bool _isRestaurantExpanded = false;
  bool _isCuisineExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _loadCuisineTypes();
    _loadRestaurantFeatures();
    _loadDietaryRequirements();
    _excludedCuisines.addAll(
      List<String>.from(widget.initialPreferences['excluded_cuisines'] ?? [])
    );
    _selectedFeatures.addAll(
      List<String>.from(widget.initialPreferences['restaurant_preferences'] ?? [])
    );
    _selectedDietaryRequirements.addAll(
      List<String>.from(widget.initialPreferences['dietary_requirements'] ?? [])
    );
  }

  Future<void> _loadRestaurantPreferences() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all feature columns from restaurants_features table
      final featureFields = await _supabase
          .from('restaurants_features')
          .select()
          .limit(1);  // We just need the structure, not the data

      if (mounted && featureFields.isNotEmpty) {
        // Get all boolean columns except id and updated_at
        final allFeatures = (featureFields[0] as Map<String, dynamic>)
            .entries
            .where((e) => e.key != 'id' && e.key != 'updated_at')
            .map((e) => e.key.replaceAll('_', ' ').toTitleCase())  // Convert to display names
            .toList();

        setState(() {
          _restaurantFeatures = allFeatures;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading restaurant preferences: $e');
      print('Error details: ${e.toString()}');
      if (mounted) {
        setState(() {
          _error = 'Failed to load restaurant preferences';
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Error: No user ID found');
        return;
      }

      print('Current user ID: $userId');
      print('Saving restaurant preferences: $_selectedFeatures');
      print('Saving dietary requirements: ${_dietaryRequirements.entries.where((e) => e.value).map((e) => e.key.replaceAll('_', ' ').toTitleCase()).toList()}');
      print('Saving excluded cuisines: $_excludedCuisines');

      // Get selected dietary requirements
      final selectedDietaryRequirements = _dietaryRequirements.entries
          .where((e) => e.value)
          .map((e) => e.key.replaceAll('_', ' ').toTitleCase())
          .toList();

      final data = {
        'dietary_requirements': selectedDietaryRequirements,
        'restaurant_preferences': _selectedFeatures,
        'excluded_cuisines': _excludedCuisines,
      };

      print('Saving data to profiles: $data');

      // Update preferences in profiles table
      final response = await _supabase
          .from('profiles')
          .update(data)
          .eq('id', userId)
          .select();

      print('Supabase response: $response');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved successfully')),
        );
      }
    } catch (e) {
      print('Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preferences'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadDietaryRequirements() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      print('Loading dietary requirements...');
      // First get all possible dietary requirements from restaurants_dietary_compliance
      final dietaryFields = await _supabase
          .from('restaurants_dietary_compliance')
          .select()
          .limit(1);

      print('Dietary fields response: $dietaryFields');

      if (mounted && dietaryFields.isNotEmpty) {
        // Get all boolean columns except id and updated_at
        final allRequirements = (dietaryFields[0] as Map<String, dynamic>)
            .entries
            .where((e) => e.key != 'id' && e.key != 'updated_at')
            .map((e) => e.key.replaceAll('_', ' ').toTitleCase())  // Convert to display names
            .toList();

        print('All requirements found: $allRequirements');
        print('Current selected requirements: $_selectedDietaryRequirements');

        setState(() {
          // Initialize the map with all requirements set to false initially
          _dietaryRequirements = Map.fromEntries(
            allRequirements.map((req) => MapEntry(req, _selectedDietaryRequirements.contains(req)))
          );
          print('Initialized dietary requirements map: $_dietaryRequirements');
          _loading = false;
        });
      } else {
        print('No dietary fields found or response was empty');
        // Fallback to hardcoded dietary requirements if no data is found
        final fallbackRequirements = [
          'Vegetarian',
          'Vegan',
          'Halal',
          'Kosher',
          'Gluten Free',
          'Dairy Free',
          'Nut Free',
          'Shellfish Free'
        ];
        setState(() {
          _dietaryRequirements = Map.fromEntries(
            fallbackRequirements.map((req) => MapEntry(req, _selectedDietaryRequirements.contains(req)))
          );
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading dietary requirements: $e');
      print('Error details: ${e.toString()}');
      if (mounted) {
        setState(() {
          _error = 'Failed to load dietary requirements';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveDietaryRequirements() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get the selected requirements (where value is true)
      final selectedRequirements = _dietaryRequirements.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      // Update requirements in profiles table
      await _supabase
          .from('profiles')
          .update({
            'dietary_requirements': selectedRequirements,
          })
          .eq('id', userId);
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

  Future<void> _loadRestaurantFeatures() async {
    setState(() => _loading = true);
    try {
      // Get all boolean columns from restaurants_features table
      final response = await _supabase
          .from('restaurants_features')
          .select()
          .limit(1);  // We just need the structure, not the data
      
      if (mounted && response.isNotEmpty) {
        // Get all boolean columns except id and updated_at
        final features = (response[0] as Map<String, dynamic>)
            .entries
            .where((e) => e.key != 'id' && e.key != 'updated_at')
            .map((e) => e.key.replaceAll('_', ' ').toTitleCase())  // Convert to display names
            .toList();
        
        setState(() {
          _restaurantFeatures = features;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading restaurant features: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load restaurant features';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('dietary_requirements, restaurant_preferences, excluded_cuisines')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          // Handle dietary requirements
          _selectedDietaryRequirements = List<String>.from(profile['dietary_requirements'] ?? []);

          // Handle restaurant preferences
          _selectedFeatures = List<String>.from(profile['restaurant_preferences'] ?? []);
          print('Loaded restaurant preferences: $_selectedFeatures'); // Debug log

          // Handle excluded cuisines
          _excludedCuisines = List<String>.from(profile['excluded_cuisines'] ?? []);

          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading user preferences: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load preferences';
          _loading = false;
        });
      }
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
                            label: Text(entry.key),
                            selected: entry.value,
                            onSelected: (selected) {
                              setState(() {
                                _dietaryRequirements[entry.key] = selected;
                                if (selected) {
                                  if (!_selectedDietaryRequirements.contains(entry.key)) {
                                    _selectedDietaryRequirements.add(entry.key);
                                  }
                                } else {
                                  _selectedDietaryRequirements.remove(entry.key);
                                }
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
                        children: _restaurantFeatures.map((feature) {
                          final isSelected = _selectedFeatures.contains(feature);
                          return FilterChip(
                            label: Text(feature),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedFeatures.add(feature);
                                } else {
                                  _selectedFeatures.remove(feature);
                                }
                              });
                              print('Selected features: $_selectedFeatures'); // Debug log
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
              await _savePreferences();
              widget.onPreferencesSaved({
                'excluded_cuisines': _excludedCuisines,
                'restaurant_preferences': _selectedFeatures,
                'dietary_requirements': _selectedDietaryRequirements,
              });
            },
            child: const Text('Save Preferences'),
          ),
        ),
      ),
    );
  }
}