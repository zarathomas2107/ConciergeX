import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class SearchResponse {
  final List<Restaurant> restaurants;
  final List<Map<String, dynamic>> availableGroups;
  final bool showingGroups;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? groupPreferences;
  final Map<String, dynamic>? location;

  SearchResponse({
    required this.restaurants,
    required this.availableGroups,
    required this.showingGroups,
    this.preferences,
    this.groupPreferences,
    this.location,
  });
}

class RestaurantService {
  final _supabase = Supabase.instance.client;
  final String _baseUrl = 'https://restaurant-search-api-378538476539.europe-west2.run.app';

  Future<SearchResponse> searchWithAgent(String searchQuery, String userId) async {
    try {
      // Get group preferences first
      final groups = await getAvailableGroups(userId);
      Map<String, dynamic>? groupPrefs;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': searchQuery,
          'user_id': userId,
          'groups': groups,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Search failed with status ${response.statusCode}: ${response.body}');
        throw Exception('Search failed: ${response.body}');
      }

      final data = json.decode(response.body);
      debugPrint('Search result: $data');
      
      // If available_groups is present in the response, return it
      if (data.containsKey('available_groups')) {
        return SearchResponse(
          restaurants: [],
          availableGroups: List<Map<String, dynamic>>.from(data['available_groups'] ?? []),
          showingGroups: true,
          preferences: data['preferences'] as Map<String, dynamic>?,
          groupPreferences: groupPrefs,
          location: data['location'] as Map<String, dynamic>?,
        );
      }

      // Extract preferences from the response
      final preferences = data['preferences'] as Map<String, dynamic>?;
      final mentionedGroup = preferences?['group'] as String?;
      
      // Find the specific group mentioned in the query
      if (mentionedGroup != null && groups.isNotEmpty) {
        debugPrint('Found group mention: $mentionedGroup');
        final matchingGroup = groups.firstWhere(
          (group) => group['name'].toString().toLowerCase() == mentionedGroup.toLowerCase(),
          orElse: () => {},
        );
        
        if (matchingGroup.isNotEmpty) {
          debugPrint('Found matching group: ${matchingGroup['name']}');
          final members = matchingGroup['members'] as List<dynamic>;
          
          // Combine all members' preferences
          List<String> allDietaryRequirements = [];
          List<String> allExcludedCuisines = [];
          List<String> allRestaurantPreferences = [];
          
          for (var member in members) {
            final memberPrefs = member as Map<String, dynamic>;
            if (memberPrefs['dietary_requirements'] != null) {
              var dietaryReqs = memberPrefs['dietary_requirements'];
              if (dietaryReqs is List) {
                allDietaryRequirements.addAll(dietaryReqs.map((e) => e.toString()));
              } else if (dietaryReqs is String) {
                allDietaryRequirements.add(dietaryReqs);
              }
            }
            if (memberPrefs['excluded_cuisines'] != null) {
              var excludedCuisines = memberPrefs['excluded_cuisines'];
              if (excludedCuisines is List) {
                allExcludedCuisines.addAll(excludedCuisines.map((e) => e.toString()));
              } else if (excludedCuisines is String) {
                allExcludedCuisines.add(excludedCuisines);
              }
            }
            if (memberPrefs['restaurant_preferences'] != null) {
              var restaurantPrefs = memberPrefs['restaurant_preferences'];
              if (restaurantPrefs is List) {
                allRestaurantPreferences.addAll(restaurantPrefs.map((e) => e.toString()));
              } else if (restaurantPrefs is String) {
                allRestaurantPreferences.add(restaurantPrefs);
              }
            }
          }
          
          // Filter out empty values and create group preferences
          allDietaryRequirements = allDietaryRequirements.where((x) => x.isNotEmpty).toSet().toList();
          allExcludedCuisines = allExcludedCuisines.where((x) => x.isNotEmpty).toSet().toList();
          allRestaurantPreferences = allRestaurantPreferences.where((x) => x.isNotEmpty && x != '[]').toSet().toList();
          
          // Only create group preferences if we have actual preferences
          if (allDietaryRequirements.isNotEmpty || allExcludedCuisines.isNotEmpty || allRestaurantPreferences.isNotEmpty) {
            groupPrefs = {
              'name': mentionedGroup,
              'dietary_requirements': allDietaryRequirements,
              'excluded_cuisines': allExcludedCuisines,
              'restaurant_preferences': allRestaurantPreferences,
            };
            debugPrint('Created group preferences with filtered data:');
            debugPrint('- Name: ${groupPrefs['name']}');
            debugPrint('- Dietary: ${groupPrefs['dietary_requirements']}');
            debugPrint('- Excluded: ${groupPrefs['excluded_cuisines']}');
            debugPrint('- Preferences: ${groupPrefs['restaurant_preferences']}');
          } else {
            debugPrint('No non-empty preferences found for group $mentionedGroup');
          }
        } else {
          debugPrint('No matching group found for $mentionedGroup');
        }
      }
      
      // Get excluded cuisines from both sources
      List<String> allExcludedCuisines = [];
      
      // Add API excluded cuisines
      if (preferences?['excluded_cuisines'] != null) {
        var apiExcluded = preferences!['excluded_cuisines'];
        if (apiExcluded is List) {
          allExcludedCuisines.addAll(List<String>.from(apiExcluded));
        } else if (apiExcluded is String) {
          allExcludedCuisines.add(apiExcluded);
        }
      }
      
      // Add group excluded cuisines if a group is mentioned
      if (mentionedGroup != null && groupPrefs?['excluded_cuisines'] != null) {
        var groupExcluded = groupPrefs!['excluded_cuisines'];
        if (groupExcluded is List) {
          allExcludedCuisines.addAll(List<String>.from(groupExcluded));
        } else if (groupExcluded is String) {
          allExcludedCuisines.add(groupExcluded);
        }
      }
      
      // Remove duplicates
      allExcludedCuisines = allExcludedCuisines.toSet().toList();
      
      debugPrint('Filtering with excluded cuisines: $allExcludedCuisines');

      // Get cuisine types
      List<String> cuisineTypes = [];
      if (preferences?['cuisine_types'] != null) {
        var apiCuisines = preferences!['cuisine_types'];
        if (apiCuisines is List) {
          cuisineTypes.addAll(List<String>.from(apiCuisines));
        } else if (apiCuisines is String) {
          cuisineTypes.add(apiCuisines);
        }
      }

      // Get venue location from the response
      final venue = data['location'] as Map<String, dynamic>?;
      if (venue == null) {
        debugPrint('No venue information found in response');
        throw Exception('No venue information found in response');
      }

      final venueName = venue['name'] as String?;
      if (venueName == null) {
        debugPrint('No venue name found in response');
        throw Exception('No venue name found in response');
      }

      debugPrint('Looking up coordinates for venue: $venueName');

      // Get venue coordinates from points_of_interest table
      final venueResponse = await _supabase
          .from('points_of_interest')
          .select('latitude, longitude')
          .eq('name', venueName)
          .single();

      if (venueResponse == null) {
        debugPrint('Venue not found in points_of_interest table: $venueName');
        throw Exception('Venue not found in points_of_interest table');
      }

      final venueLat = venueResponse['latitude'] as double;
      final venueLon = venueResponse['longitude'] as double;
      final pointText = 'POINT($venueLon $venueLat)';
      debugPrint('Created point text from coordinates: $pointText');

      try {
        // Get nearby restaurants using ST_DWithin directly
        final restaurantsResponse = await _supabase
            .rpc('get_restaurants_within_distance', params: {
              'ref_point': pointText,
              'max_distance': 5000.0,  // 5km radius
              'excluded_cuisines': allExcludedCuisines,
            });

        debugPrint('Raw response from get_restaurants_within_distance: $restaurantsResponse');

        // Convert the response data to Restaurant objects
        final restaurants = (restaurantsResponse as List<dynamic>)
            .map((data) {
              debugPrint('Processing restaurant data: $data');
              return Restaurant.fromJson({
                'id': data['id'],
                'name': data['name'],
                'address': data['address'],
                'rating': data['rating'],
                'price_level': data['price_level'],
                'cuisine_type': data['cuisine_type'],
                'business_status': data['business_status'],
                'website': data['website'],
                'distance_meters': data['distance'],
                'latitude': data['latitude'],
                'longitude': data['longitude'],
              });
            })
            .where((restaurant) => 
              !allExcludedCuisines.contains(restaurant.cuisineType) &&
              (cuisineTypes.isEmpty || cuisineTypes.contains(restaurant.cuisineType))
            )
            .toList();

        debugPrint('Found ${restaurants.length} restaurants matching criteria');
        for (var restaurant in restaurants) {
          debugPrint('Restaurant: ${restaurant.name}, Distance: ${restaurant.distance}m');
        }

        return SearchResponse(
          restaurants: restaurants,
          availableGroups: [],
          showingGroups: false,
          preferences: preferences,
          groupPreferences: groupPrefs,
          location: data['location'] as Map<String, dynamic>?,
        );
      } catch (e, stackTrace) {
        debugPrint('Error getting restaurants: $e');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
      
    } catch (e) {
      debugPrint('Error in searchWithAgent: $e');
      return SearchResponse(
        restaurants: [],
        availableGroups: [],
        showingGroups: false,
        preferences: null,
        groupPreferences: null,
        location: null,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableGroups(String userId) async {
    try {
      debugPrint('Getting available groups for user: $userId');
      final response = await _supabase
          .rpc('get_group_members_preferences', params: {
            'user_id': userId
          });
      
      debugPrint('Got response from get_group_members_preferences: $response');
      final groups = List<Map<String, dynamic>>.from(response);
      debugPrint('Parsed groups: $groups');
      return groups;
    } catch (e, stackTrace) {
      debugPrint('Error getting available groups: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }
} 