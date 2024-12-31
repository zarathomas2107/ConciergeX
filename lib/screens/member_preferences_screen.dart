import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';

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
  List<String> _dietaryRequirements = [];
  List<String> _restaurantPreferences = [];
  List<String> _locationPreferences = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _loading = true);

    try {
      _dietaryRequirements = widget.member.dietaryRequirements;
      _restaurantPreferences = widget.member.restaurantPreferences;
      _locationPreferences = widget.member.locationPreferences;
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _savePreferences() async {
    try {
      await _supabase.from('group_members').update({
        'dietary_requirements': _dietaryRequirements,
        'restaurant_preferences': _restaurantPreferences,
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
                _buildSection(
                  title: 'Dietary Requirements',
                  items: _dietaryRequirements,
                  onAdd: _addDietaryRequirement,
                  onRemove: (item) {
                    setState(() {
                      _dietaryRequirements.remove(item);
                    });
                  },
                ),
                const Divider(height: 32),
                _buildSection(
                  title: 'Restaurant Preferences',
                  items: _restaurantPreferences,
                  onAdd: _addRestaurantPreference,
                  onRemove: (item) {
                    setState(() {
                      _restaurantPreferences.remove(item);
                    });
                  },
                ),
                const Divider(height: 32),
                _buildSection(
                  title: 'Location Preferences',
                  items: _locationPreferences,
                  onAdd: _addLocationPreference,
                  onRemove: (item) {
                    setState(() {
                      _locationPreferences.remove(item);
                    });
                  },
                ),
              ],
            ),
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
              icon: const Icon(Icons.add),
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

  Future<void> _addDietaryRequirement() async {
    final requirement = await _showAddDialog(
      title: 'Add Dietary Requirement',
      hint: 'e.g., Vegetarian, Gluten-free',
    );
    if (requirement != null) {
      setState(() {
        _dietaryRequirements.add(requirement);
      });
    }
  }

  Future<void> _addRestaurantPreference() async {
    final preference = await _showAddDialog(
      title: 'Add Restaurant Preference',
      hint: 'e.g., Italian, Fine Dining',
    );
    if (preference != null) {
      setState(() {
        _restaurantPreferences.add(preference);
      });
    }
  }

  Future<void> _addLocationPreference() async {
    final preference = await _showAddDialog(
      title: 'Add Location Preference',
      hint: 'e.g., Covent Garden, Soho',
    );
    if (preference != null) {
      setState(() {
        _locationPreferences.add(preference);
      });
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