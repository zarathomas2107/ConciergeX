import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../widgets/restaurant_card.dart';
import '../services/restaurant_service.dart';
import 'dart:math';

class PreferencesSummary extends StatelessWidget {
  final Map<String, dynamic> preferences;

  const PreferencesSummary({
    Key? key,
    required this.preferences,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dietaryRequirements = preferences['dietary_requirements'] as List? ?? [];
    final excludedCuisines = preferences['excluded_cuisines'] as List? ?? [];

    if (dietaryRequirements.isEmpty && excludedCuisines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: Border(
        bottom: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.filter_list, size: 20),
            const SizedBox(width: 8),
            Text(
              'Group Preferences',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dietaryRequirements.isNotEmpty) ...[
                  Text(
                    'Dietary Requirements:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: dietaryRequirements.map((req) => Chip(
                      label: Text(
                        req.toString().replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.green.withOpacity(0.1),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
                if (excludedCuisines.isNotEmpty) ...[
                  if (dietaryRequirements.isNotEmpty)
                    const SizedBox(height: 8),
                  Text(
                    'Excluded Cuisines:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: excludedCuisines.map((cuisine) => Chip(
                      label: Text(
                        cuisine.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.red.withOpacity(0.1),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Restaurant> restaurants;
  final Function(List<Restaurant>) onRestaurantsUpdated;

  const HomeScreen({
    Key? key,
    required this.restaurants,
    required this.onRestaurantsUpdated,
  }) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Restaurant> _restaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  List<Map<String, dynamic>> _availableGroups = [];
  bool _isSearching = false;
  bool _showingGroups = false;
  Map<String, dynamic> _currentPreferences = {};
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _restaurants = widget.restaurants;
    _filteredRestaurants = _restaurants;
  }

  Future<void> filterRestaurants(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredRestaurants = _restaurants;
        _availableGroups = [];
        _showingGroups = false;
        _isSearching = false;
        _currentPreferences = {};
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final restaurantService = RestaurantService();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final searchResponse = await restaurantService.searchWithAgent(query, userId);
      
      setState(() {
        _filteredRestaurants = searchResponse.restaurants;
        _availableGroups = searchResponse.availableGroups;
        _showingGroups = searchResponse.showingGroups;
        _isSearching = false;
        _currentPreferences = searchResponse.preferences ?? {};
      });

      // Debug print
      if (!_showingGroups) {
        for (var restaurant in _filteredRestaurants) {
          print('Restaurant: ${restaurant.name}, Distance: ${restaurant.distance}m');
        }
      }
    } catch (e) {
      print('Error filtering restaurants: $e');
      setState(() {
        _filteredRestaurants = [];
        _availableGroups = [];
        _showingGroups = false;
        _isSearching = false;
        _currentPreferences = {};
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PreferencesSummary(preferences: _currentPreferences),
            Expanded(
              child: _isSearching 
                ? const Center(child: CircularProgressIndicator())
                : _showingGroups
                  ? _availableGroups.isEmpty
                    ? const Center(child: Text('No groups found'))
                    : _buildGroupSuggestions()
                  : _filteredRestaurants.isEmpty
                    ? const Center(
                        child: Text('No restaurants found. Try a different search.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _filteredRestaurants.length,
                        itemBuilder: (context, index) {
                          final restaurant = _filteredRestaurants[index];
                          return RestaurantCard(
                            restaurant: restaurant,
                            onTap: () {
                              // Handle restaurant selection
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _availableGroups.length,
      itemBuilder: (context, index) {
        final group = _availableGroups[index];
        return ListTile(
          leading: const Icon(Icons.group),
          title: Text(group['name'] ?? 'Unnamed Group'),
          onTap: () {
            // When a group is selected, update the search query with the group name
            // You'll need to implement this callback
          },
        );
      },
    );
  }
}