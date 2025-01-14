import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../utils/string_extensions.dart';
import '../widgets/multi_select_location_dialog.dart';

class MemberPreferencesScreen extends StatefulWidget {
  final GroupMember member;
  final String groupId;
  final bool isCreator;
  final VoidCallback onRemoveMember;

  const MemberPreferencesScreen({
    Key? key,
    required this.member,
    required this.groupId,
    required this.isCreator,
    required this.onRemoveMember,
  }) : super(key: key);

  @override
  _MemberPreferencesScreenState createState() => _MemberPreferencesScreenState();
}

class _MemberPreferencesScreenState extends State<MemberPreferencesScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, List<String>> _groupedLocations = {};
  
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

  // Store selected preferences
  List<String> _selectedDietaryRequirements = [];
  List<String> _selectedRestaurantPreferences = [];
  List<String> _excludedCuisines = [];
  List<String> _otherRequirements = [];
  List<String> _otherRestaurantPreferences = [];
  List<String> _locationPreferences = [];
  bool _loading = true;
  bool _isDietaryExpanded = false;
  bool _isRestaurantExpanded = false;
  bool _isLocationExpanded = false;
  bool _isCuisineExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final response = await _supabase
          .from('restaurants')
          .select('area')
          .not('area', 'is', null)
          .order('area', ascending: true);
      
      final areas = <String>{};  // Using a Set for unique values
      final seenAreas = <String>{};  // Track lowercase versions for case-insensitive uniqueness
      
      for (final row in response) {
        final area = row['area'] as String;
        final lowerArea = area.toLowerCase();
        
        if (!seenAreas.contains(lowerArea)) {
          seenAreas.add(lowerArea);
          areas.add(area);
        }
      }
      
      setState(() {
        _groupedLocations = {
          'Areas': areas.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
        };
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
      _excludedCuisines = List<String>.from(widget.member.excludedCuisines);

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
    setState(() => _loading = true);
    
    try {
      final allDietaryRequirements = [
        ..._selectedDietaryRequirements,
        ..._otherRequirements,
      ];

      final allRestaurantPreferences = [
        ..._selectedRestaurantPreferences,
        ..._otherRestaurantPreferences,
      ];

      // Update all preferences in the profiles table
      await _supabase.from('profiles').update({
        'dietary_requirements': allDietaryRequirements,
        'restaurant_preferences': allRestaurantPreferences,
        'location_preferences': _locationPreferences,
        'excluded_cuisines': _excludedCuisines,
      }).eq('id', widget.member.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
        Navigator.of(context).pop(false);  // Return false to indicate member was not removed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.member.name),
        actions: [
          // Save button
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePreferences,
          ),
          // Show remove button if:
          // 1. Current user is the creator and not removing themselves
          // 2. Current user is removing themselves
          if ((widget.isCreator && widget.member.id != _supabase.auth.currentUser?.id) ||
              (!widget.isCreator && widget.member.id == _supabase.auth.currentUser?.id))
            IconButton(
              icon: const Icon(Icons.person_remove),
              onPressed: _confirmRemoveMember,
              color: Colors.red,
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
                    title: const Text(
                      'Dietary Requirements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() => _isDietaryExpanded = expanded);
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
                      'Excluded Cuisines',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    initiallyExpanded: _isCuisineExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _isCuisineExpanded = expanded);
                    },
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

  Future<void> _confirmRemoveMember() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      widget.onRemoveMember();
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate member was removed
      }
    }
  }
} 