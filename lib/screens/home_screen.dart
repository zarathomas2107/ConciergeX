import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../widgets/restaurant_card.dart';
import '../services/ai_service.dart';
import 'dart:convert';
import 'dart:math';

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
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final _aiService = AIService();
  final _supabase = Supabase.instance.client;
  final Map<String, Map<String, double>> locationCoords = {
    'Covent Garden': {'lat': 51.5117, 'lon': -0.1240},
    'Soho': {'lat': 51.5137, 'lon': -0.1337},
    'Lyceum': {'lat': 51.5115, 'lon': -0.1200},
  };

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
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await _aiService.processSearchQuery(query, userId);
        
        // Get venue coordinates if available
        double? venueLat, venueLon;
        final location = response['location'] as String? ?? 'Covent Garden';
        
        if (response['venue_name'] != null) {
          // Try to get venue coordinates first
          final defaultCoords = locationCoords['Covent Garden']!;
          final coords = locationCoords[location] ?? defaultCoords;
          
          try {
            final venues = await _aiService.getNearbyVenues(
              coords['lat']!, 
              coords['lon']!,
              venueName: response['venue_name'] as String,
            );
            
            if (venues.isNotEmpty) {
              final venue = venues.first;
              venueLat = venue['latitude'] as double?;
              venueLon = venue['longitude'] as double?;
              if (venueLat != null && venueLon != null) {
                print('Using venue coordinates: ${venue['name']} at (${venueLat}, ${venueLon})');
              }
            }
          } catch (e) {
            print('Error finding venue: $e');
          }
        }
        
        // If no venue found or no venue specified, use location coordinates
        if (venueLat == null || venueLon == null) {
          final coords = locationCoords[location] ?? locationCoords['Covent Garden']!;
          venueLat = coords['lat'];
          venueLon = coords['lon'];
          print('Using location coordinates for $location: ($venueLat, $venueLon)');
        }

        // Search for restaurants
        final results = await _aiService.searchRestaurants(
          searchTerm: response['cuisine_type'] ?? query,
          groupIds: List<String>.from(response['group_ids'] ?? []),
          userPreferences: null, // Add user preferences if needed
        );

        // Convert results to Restaurant objects and calculate distances
        final restaurants = results.map((json) {
          if (json['Latitude'] != null && json['Longitude'] != null) {
            final distance = _aiService.calculateDistance(
              venueLat!,
              venueLon!,
              json['Latitude'] as double,
              json['Longitude'] as double
            );
            json['distance'] = distance;
          }
          print('Loading restaurants with data: $json');
          final restaurant = Restaurant.fromJson(json);
          print('Created restaurant with ID: ${restaurant.restaurantId}');
          return restaurant;
        }).toList();

        // Sort by distance
        restaurants.sort((a, b) => 
          (a.distance ?? double.infinity)
          .compareTo(b.distance ?? double.infinity)
        );

        setState(() {
          _filteredRestaurants = restaurants;
          _isSearching = false;
        });

        // Debug print
        for (var restaurant in restaurants) {
          print('Restaurant: ${restaurant.name}, Distance: ${restaurant.distance}m');
        }
      }
    } catch (e) {
      print('Error filtering restaurants: $e');
      setState(() {
        _filteredRestaurants = [];
        _isSearching = false;
      });
    }
  }

  // Helper method to extract values from JSON string
  String? extractValue(String jsonString, String key) {
    try {
      final regex = RegExp('"$key":\\s*"([^"]*)"');
      final match = regex.firstMatch(jsonString);
      return match?.group(1);
    } catch (e) {
      print('Error extracting $key: $e');
      return null;
    }
  }

  // Add this helper method to calculate distance
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3; // Earth's radius in meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi/2) * sin(deltaPhi/2) +
            cos(phi1) * cos(phi2) *
            sin(deltaLambda/2) * sin(deltaLambda/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c; // Distance in meters
  }

  Future<void> _performSearch(String query) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      final response = await _aiService.processSearchQuery(query, userId);
      // ... rest of the search logic
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Loading indicator or results
            Expanded(
              child: _isSearching 
                ? const Center(child: CircularProgressIndicator())
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}