import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../utils/string_extensions.dart';
import '../widgets/multi_select_location_dialog.dart';

class MemberPreferencesScreen extends StatefulWidget {
  final GroupMember member;
  final String groupId;

  const MemberPreferencesScreen({
    Key? key,
    required this.member,
    required this.groupId,
  }) : super(key: key);

  @override
  _MemberPreferencesScreenState createState() => _MemberPreferencesScreenState();
}

class _MemberPreferencesScreenState extends State<MemberPreferencesScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, List<String>> _groupedLocations = {};
  
  // Define available options
  final List<String> _availableDietaryRequirements = [
    'vegetarian',
    'vegan',
    'pescatarian',
    'halal',
    'kosher',
    'gluten_free',
    'dairy_free',
    'nut_free',
    'shellfish_allergy',
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

  // Store selected preferences
  List<String> _selectedDietaryRequirements = [];
  List<String> _selectedRestaurantPreferences = [];
  List<String> _otherRequirements = [];
  List<String> _otherRestaurantPreferences = [];
  List<String> _locationPreferences = [];
  bool _loading = true;
  bool _isDietaryExpanded = true;
  bool _isRestaurantExpanded = true;
  bool _isLocationExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final response = await _supabase
          .from('london_areas')
          .select('name, area_type')
          .order('area_type', ascending: false)
          .order('name');
      
      final groupedData = <String, List<String>>{};
      
      for (final row in response) {
        final areaType = (row['area_type'] as String?) ?? 'Other';
        final name = row['name'] as String;
        
        if (!groupedData.containsKey(areaType)) {
          groupedData[areaType] = [];
        }
        groupedData[areaType]!.add(name);
      }
      
      setState(() {
        _groupedLocations = groupedData;
      });
    } catch (e) {
      debugPrint('Error loading locations: $e');
    }
  }

  Future<void> _loadPreferences() async {
    setState(() => _loading = true);

    try {
      // Initialize preferences from member data
      _selectedDietaryRequirements = List<String>.from(widget.member.dietaryRequirements);
      _selectedRestaurantPreferences = List<String>.from(widget.member.restaurantPreferences);
      _locationPreferences = List<String>.from(widget.member.locationPreferences);

      // Separate standard and other requirements
      _otherRequirements = _selectedDietaryRequirements
          .where((req) => !_availableDietaryRequirements.contains(req))
          .toList();
      _selectedDietaryRequirements = _selectedDietaryRequirements
          .where((req) => _availableDietaryRequirements.contains(req))
          .toList();

      // Separate standard and other restaurant preferences
      _otherRestaurantPreferences = _selectedRestaurantPreferences
          .where((pref) => !_availableRestaurantPreferences.contains(pref))
          .toList();
      _selectedRestaurantPreferences = _selectedRestaurantPreferences
          .where((pref) => _availableRestaurantPreferences.contains(pref))
          .toList();

    } catch (e, stackTrace) {
      debugPrint('Error loading preferences: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _savePreferences() async {
    try {
      final allDietaryRequirements = [
        ..._selectedDietaryRequirements,
        ..._otherRequirements,
      ];

      final allRestaurantPreferences = [
        ..._selectedRestaurantPreferences,
        ..._otherRestaurantPreferences,
      ];

      await _supabase.from('group_members').update({
        'dietary_requirements': allDietaryRequirements,
        'restaurant_preferences': allRestaurantPreferences,
        'location_preferences': _locationPreferences,
      }).eq('id', widget.member.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preferences: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${widget.member.name}\'s Preferences'),
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
                    title: const Text('Dietary Requirements'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableDietaryRequirements.map((requirement) {
                                return FilterChip(
                                  label: Text(requirement.replaceAll('_', ' ').toTitleCase()),
                                  selected: _selectedDietaryRequirements.contains(requirement),
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
                            if (_otherRequirements.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Other Requirements',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: const Text(
                      'Restaurant Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    initiallyExpanded: _isRestaurantExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _isRestaurantExpanded = expanded);
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableRestaurantPreferences.map((preference) {
                                return FilterChip(
                                  label: Text(preference.replaceAll('_', ' ').toTitleCase()),
                                  selected: _selectedRestaurantPreferences.contains(preference),
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
                            const SizedBox(height: 24),
                            _buildOtherRestaurantPreferencesSection(),
                          ],
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    initiallyExpanded: _isLocationExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _isLocationExpanded = expanded);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: ImageIcon(
                            const AssetImage('assets/Icons/add.png'),
                            size: 24,
                            color: Colors.white,
                          ),
                          onPressed: _addLocationPreference,
                        ),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _locationPreferences.map((item) {
                            return Chip(
                              label: Text(item),
                              onDeleted: () {
                                setState(() => _locationPreferences.remove(item));
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

  Widget _buildOtherRestaurantPreferencesSection() {
    return Column(
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
    );
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
    if (_groupedLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading available locations...')),
      );
      return;
    }

    final selectedLocations = await showDialog<List<String>>(
      context: context,
      builder: (context) => MultiSelectLocationDialog(
        groupedLocations: _groupedLocations,
        currentSelections: _locationPreferences,
      ),
    );

    if (selectedLocations != null && mounted) {
      setState(() => _locationPreferences = selectedLocations);
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