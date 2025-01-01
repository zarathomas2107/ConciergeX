import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, bool> _dietaryRequirements = {
    'vegetarian': false,
    'vegan': false,
    'pescatarian': false,
    'halal': false,
    'kosher': false,
    'gluten_free': false,
    'dairy_free': false,
    'nut_free': false,
    'shellfish_allergy': false,
  };
  List<String> _otherRequirements = [];
  Map<String, bool> _restaurantPreferences = {
    'Dog_Friendly': false,
    'Business_Meals': false,
    'Birthdays': false,
    'Date_Nights': false,
    'Pre_Theatre': false,
    'Cheap_Eat': false,
    'Fine_Dining': false,
    'Family_Friendly': false,
    'Solo': false,
    'Bar': false,
    'Casual_Dinner': false,
    'Brunch': false,
    'Breakfast': false,
    'Lunch': false,
    'Dinner': false,
  };
  List<String> _otherRestaurantPreferences = [];
  List<String> _locationPreferences = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load profile data (location preferences)
      final profileData = await _supabase
          .from('profiles')
          .select('location_preferences')
          .eq('id', userId)
          .single();

      // Load dietary requirements
      final dietaryData = await _supabase
          .from('user_dietary_requirements')
          .select()
          .eq('profile_id', userId)
          .maybeSingle();

      if (dietaryData != null) {
        setState(() {
          _dietaryRequirements = Map.fromEntries(
            _dietaryRequirements.keys.map((key) => 
              MapEntry(key, dietaryData[key] ?? false)
            ),
          );
          _otherRequirements = List<String>.from(dietaryData['other_requirements'] ?? []);
        });
      }

      // Load restaurant preferences
      final restaurantData = await _supabase
          .from('user_restaurant_preferences')
          .select()
          .eq('profile_id', userId)
          .maybeSingle();

      if (restaurantData != null) {
        setState(() {
          _restaurantPreferences = Map.fromEntries(
            _restaurantPreferences.keys.map((key) => 
              MapEntry(key, restaurantData[key] ?? false)
            ),
          );
          _otherRestaurantPreferences = List<String>.from(restaurantData['other_preferences'] ?? []);
        });
      }

      setState(() {
        _locationPreferences = List<String>.from(profileData['location_preferences'] ?? []);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _savePreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Save dietary requirements
      await _supabase.from('user_dietary_requirements').upsert({
        'profile_id': userId,
        ..._dietaryRequirements,
        'other_requirements': _otherRequirements,
      });

      // Save restaurant preferences
      await _supabase.from('user_restaurant_preferences').upsert({
        'profile_id': userId,
        ..._restaurantPreferences,
        'other_preferences': _otherRestaurantPreferences,
      });

      // Save location preferences
      await _supabase.from('profiles').update({
        'location_preferences': _locationPreferences,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ImageIcon(
              const AssetImage('assets/Icons/profile-user.png'),
              color: Colors.white,
            ),
          ),
        ),
        title: const Text('My Preferences'),
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
                _buildDietaryRequirements(),
                const Divider(height: 32),
                _buildRestaurantPreferences(),
                const Divider(height: 32),
                _buildSection(
                  title: 'Location Preferences',
                  items: _locationPreferences,
                  onAdd: _addLocationPreference,
                  onRemove: (item) {
                    setState(() => _locationPreferences.remove(item));
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildDietaryRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dietary Requirements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Other Requirements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: ImageIcon(
                      const AssetImage('assets/Icons/add.png'),
                      size: 24,
                      color: Colors.white,
                    ),
                    onPressed: _addOtherRequirement,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _otherRequirements.map((item) {
                  return Chip(
                    label: Text(item),
                    onDeleted: () {
                      setState(() => _otherRequirements.remove(item));
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Restaurant Preferences',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Other Preferences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: ImageIcon(
                      const AssetImage('assets/Icons/add.png'),
                      size: 24,
                      color: Colors.white,
                    ),
                    onPressed: _addOtherRestaurantPreference,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _otherRestaurantPreferences.map((item) {
                  return Chip(
                    label: Text(item),
                    onDeleted: () {
                      setState(() => _otherRestaurantPreferences.remove(item));
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> items,
    required VoidCallback onAdd,
    required Function(String) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: ImageIcon(
                const AssetImage('assets/Icons/add.png'),
                size: 24,
                color: Colors.white,
              ),
              onPressed: onAdd,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return Chip(
              label: Text(item),
              onDeleted: () => onRemove(item),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _addOtherRequirement() async {
    final requirement = await _showAddDialog(
      title: 'Add Other Requirement',
      hint: 'e.g., No onions, Low FODMAP',
    );
    if (requirement != null) {
      setState(() => _otherRequirements.add(requirement));
    }
  }

  Future<void> _addOtherRestaurantPreference() async {
    final preference = await _showAddDialog(
      title: 'Add Other Restaurant Preference',
      hint: 'e.g., Wine Bar, Cocktail Bar',
    );
    if (preference != null) {
      setState(() => _otherRestaurantPreferences.add(preference));
    }
  }

  Future<void> _addLocationPreference() async {
    final preference = await _showAddDialog(
      title: 'Add Location Preference',
      hint: 'e.g., Covent Garden, Soho',
    );
    if (preference != null) {
      setState(() => _locationPreferences.add(preference));
    }
  }

  Future<String?> _showAddDialog({
    required String title,
    required String hint,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String toTitleCase() {
    return split(' ')
        .map((word) => word.isEmpty 
            ? '' 
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}