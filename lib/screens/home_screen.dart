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

  Future<void> _filterRestaurants(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredRestaurants = _restaurants;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await _aiService.processSearchQuery(query);
      final aiResponse = response['response'] as String;
      final jsonResponse = json.decode(aiResponse);
      
      // Get venue coordinates if available
      double? venueLat, venueLon;
      final location = jsonResponse['location'] as String;
      
      if (jsonResponse['venue_name'] != null) {
        // Try to get venue coordinates first
        final defaultCoords = locationCoords['Covent Garden']!;
        final coords = locationCoords[location] ?? defaultCoords;
        
        final venues = await _aiService.getNearbyVenues(
          coords['lat']!, 
          coords['lon']!,
          venueName: jsonResponse['venue_name'],
        );
        
        if (venues.isNotEmpty) {
          final venue = venues.first;
          venueLat = venue['latitude'] as double;
          venueLon = venue['longitude'] as double;
          print('Using venue coordinates: ${venue['name']} at (${venueLat}, ${venueLon})');
        }
      }
      
      // If no venue found or no venue specified, use location coordinates
      if (venueLat == null || venueLon == null) {
        final coords = locationCoords[location] ?? locationCoords['Covent Garden']!;
        venueLat = coords['lat'];
        venueLon = coords['lon'];
        print('Using location coordinates for $location: ($venueLat, $venueLon)');
      }

      if (jsonResponse.containsKey('restaurants') && 
          jsonResponse['restaurants'] is List && 
          (jsonResponse['restaurants'] as List).isNotEmpty) {
        
        final restaurants = (jsonResponse['restaurants'] as List)
            .map((json) {
              // Always calculate distance since we now always have coordinates
              final restaurantLat = json['Latitude'] as double;
              final restaurantLon = json['Longitude'] as double;
              
              final distance = calculateDistance(
                venueLat!, 
                venueLon!, 
                restaurantLat, 
                restaurantLon
              );
              
              final reference = jsonResponse['venue_name'] ?? location;
              print('Calculated distance for ${json['Name']}: ${distance.round()}m from $reference');
              
              json['distance'] = distance;
              return Restaurant.fromSupabase(json);
            })
            .toList();
        
        // Always sort by distance since we always have it now
        restaurants.sort((a, b) => 
          (a.distance ?? double.infinity)
          .compareTo(b.distance ?? double.infinity)
        );
        
        setState(() {
          _filteredRestaurants = restaurants;
          _isSearching = false;
        });
        return;
      }

      // If no restaurants in AI response, fall back to the existing logic
      final cuisineType = jsonResponse['cuisine_type'] as String;
      final similarTo = jsonResponse['similar_to'] as String?;
      final venueName = jsonResponse['venue_name'] as String?;

      List<Map<String, dynamic>> results;

      if (similarTo != null) {
        // First find the restaurant ID for the reference restaurant
        final refRestaurant = await _supabase
            .from('restaurants')
            .select()
            .ilike('Name', similarTo)
            .single();
            
        if (refRestaurant != null) {
          results = await _aiService.getSimilarRestaurants(refRestaurant['RestaurantID']);
        } else {
          results = [];
        }
      } else {
        // Default coordinates for different locations
        final Map<String, Map<String, double>> locationCoords = {
          'Covent Garden': {'lat': 51.5117, 'lon': -0.1240},
          'Soho': {'lat': 51.5137, 'lon': -0.1337},
        };

        // Get coordinates with null safety
        final defaultCoords = locationCoords['Covent Garden']!;
        final coords = Map<String, double>.from(
          locationCoords[location] ?? defaultCoords
        );
        
        if (venueName != null) {
          // Get nearby venues first
          final venues = await _aiService.getNearbyVenues(
            coords['lat']!, 
            coords['lon']!,
            venueName: venueName,
          );
          if (venues.isNotEmpty) {
            // Use the closest matching venue's coordinates
            final venue = venues.first;
            coords['lat'] = venue['latitude'] as double;
            coords['lon'] = venue['longitude'] as double;
            
            print('Found venue: ${venue['name']} at distance: ${venue['distance']} meters');
          } else {
            print('No matching venues found near the coordinates');
          }
        }
        
        // Query nearby restaurants
        results = await _supabase
            .rpc('nearby_restaurants', params: {
              'ref_lat': coords['lat']!,
              'ref_lon': coords['lon']!,
              'radius_meters': 1000.0,
            });
      }

      // Filter by cuisine type if specified
      var filteredResults = results.where((r) => 
        r['CuisineType'].toString().toLowerCase() == cuisineType.toLowerCase()
      ).toList();

      setState(() {
        _filteredRestaurants = filteredResults
            .map((json) => Restaurant.fromSupabase(json))
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      print('Error filtering restaurants: $e');
      setState(() => _isSearching = false);
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
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
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search restaurants...',
                border: OutlineInputBorder(),
                prefixIcon: null,
                suffixIcon: null,
                icon: null,
              ),
              onSubmitted: _filterRestaurants,
              textInputAction: TextInputAction.search,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}