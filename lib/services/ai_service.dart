import 'package:dart_openai/dart_openai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

class AIService {
  final _supabase = Supabase.instance.client;
  
  AIService() {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in .env file');
    }
    
    OpenAI.apiKey = apiKey;
  }

  Future<List<Map<String, dynamic>>> getSimilarRestaurants(String restaurantId) async {
    try {
      final response = await _supabase.rpc(
        'get_similar_restaurants',
        params: {
          'query_restaurant_id': restaurantId,
          'match_threshold': 0.3,
          'match_count': 5
        },
      );
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error getting similar restaurants: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyVenues(double lat, double lon, {String? venueName}) async {
    try {
      // Try theatres first
      var response = await _supabase.rpc(
        'get_nearby_theatres',
        params: {
          'p_lat': lat,
          'p_lon': lon,
          'p_radius': 1000.0,
          'p_name': venueName ?? ''
        },
      );
      
      var results = List<Map<String, dynamic>>.from(response as List);
      
      // If no theatres found, try cinemas
      if (results.isEmpty) {
        response = await _supabase.rpc(
          'get_nearby_cinemas',
          params: {
            'p_lat': lat,
            'p_lon': lon,
            'p_radius': 1000.0,
            'p_name': venueName ?? ''
          },
        );
        
        results = List<Map<String, dynamic>>.from(response as List);
      }

        // Map the results to a common format
        results = results.map((venue) {
          final isTheatre = venue['venue_type'] == 'theatre';
        final location = venue['location'] as Map<String, dynamic>?;
        final coordinates = location?['coordinates'] as List?;
        
          return {
          'id': isTheatre ? venue['place_id'] : venue['id'],
            'name': venue['name'],
            'address': venue['address'],
            'website': venue['website'],
            'distance': venue['distance'],
          'latitude': coordinates != null ? coordinates[1] : venue['latitude'],
          'longitude': coordinates != null ? coordinates[0] : venue['longitude'],
          'venue_type': venue['venue_type'] ?? (isTheatre ? 'theatre' : 'cinema')
          };
        }).toList();

      // Sort by distance
        results.sort((a, b) => 
          (a['distance'] ?? double.infinity)
          .compareTo(b['distance'] ?? double.infinity)
        );

        if (results.isNotEmpty) {
          print('Found venue: ${results.first['name']} (${results.first['distance']} meters)');
      } else {
        print('No matching venues found');
      }
      
      return results;
    } catch (e) {
      print('Error getting nearby venues: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVenuesByName(String name) async {
    try {
      // Search theatres
      var response = await _supabase
          .from('theatres')
          .select('''
            name,
            place_id,
            address,
            phone,
            website,
            rating,
            user_ratings_total,
            latitude,
            longitude,
            types,
            price_level,
            opening_hours,
            google_maps_url,
            location
          ''')
          .ilike('name', '%$name%')
          .limit(5);
      
      var results = List<Map<String, dynamic>>.from(response);
      
      // If no theatres found, search cinemas
      if (results.isEmpty) {
        response = await _supabase
            .from('cinemas')
            .select('''
              id,
              name,
              address,
              postcode,
              chain,
              website,
              location
            ''')
            .ilike('name', '%$name%')
            .limit(5);
        
        results = List<Map<String, dynamic>>.from(response);
      }

      return results.map((venue) {
        final location = venue['location'] as Map<String, dynamic>?;
        final coordinates = location?['coordinates'] as List?;
        final isTheatre = venue.containsKey('place_id');
        
        return {
          'id': venue['place_id'] ?? venue['id'],
          'name': venue['name'],
          'address': venue['address'],
          'website': venue['website'],
          'latitude': coordinates?[1] ?? venue['latitude'],
          'longitude': coordinates?[0] ?? venue['longitude'],
          'venue_type': isTheatre ? 'theatre' : 'cinema',
          if (isTheatre) ...{
            'phone': venue['phone'],
            'rating': venue['rating'],
            'price_level': venue['price_level'],
            'opening_hours': venue['opening_hours'],
            'google_maps_url': venue['google_maps_url'],
            'types': venue['types'],
          } else ...{
            'postcode': venue['postcode'],
            'chain': venue['chain'],
          }
        };
      }).toList();
    } catch (e) {
      print('Error searching venues: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> processSearchQuery(String query, String userId) async {
    try {
      print('\n=== Processing Search Query ===');
      print('Original query: $query');

      final userGroups = await getUserGroups(userId);
      print('Available user groups: ${userGroups.map((g) => g['name']).toList()}');

      final groupMentions = RegExp(r'@(\w+)').allMatches(query).map((m) => m.group(1)!).toList();
      print('Detected group mentions: $groupMentions');

      final validGroupIds = await _validateAndGetGroupIds(groupMentions, userGroups);
      print('Valid group IDs: $validGroupIds');

      final cleanQuery = query.replaceAll(RegExp(r'@\w+'), '').trim();
      print('Clean query for LLM: $cleanQuery');

      print('\n--- Sending to LLM ---');
      final completion = await OpenAI.instance.chat.create(
        model: dotenv.env['OPENAI_MODEL_ID'] ?? "ft:gpt-3.5-turbo-0125:personal::AjMYeMJb",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                """Extract structured information from the query into JSON format.
                Optional fields:
                - cuisine_type: type of cuisine if specified
                - location: specific area if mentioned
                - venue_name: if searching near a specific venue (e.g., theatre, cinema)
                - venue_type: type of venue if specified (e.g., "theatre", "cinema")
                - similar_to: if looking for similar restaurants
                - start_time: if time is mentioned
                - end_time: if time range is mentioned
                - features: array of matching features
                """
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(cleanQuery)],
          ),
        ],
      );

      print('\n--- LLM Response ---');
      final responseText = completion.choices.first.message.content?.firstOrNull?.text ?? '{}';
      print('Raw LLM response: $responseText');

      final result = json.decode(responseText) as Map<String, dynamic>;
      print('Parsed LLM result: $result');

      // Process venue information
      if (result['venue_name'] != null && result['location'] == null) {
        print('\n--- Looking up venue location ---');
        final venue = await _findVenueLocation(
          result['venue_name'] as String,
          result['venue_type'] as String?
        );
        print('Found venue: $venue');

        if (venue != null) {
          result['location'] = venue['area'] ?? _getAreaFromCoordinates(
            venue['latitude'] as double,
            venue['longitude'] as double
          );
          result['venue_details'] = venue;
          print('Updated result with venue details: $result');
        }
      }

      return result;
    } catch (e, stackTrace) {
      print('\n=== Error in processSearchQuery ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }

  Future<Map<String, dynamic>?> _findVenueLocation(String venueName, String? venueType) async {
    try {
      if (venueType?.toLowerCase() == 'cinema') {
        // Search cinemas first if specified
        final response = await _supabase
            .from('cinemas')
            .select('''
              id,
              name,
              address,
              website,
              location
            ''')
            .ilike('name', '%$venueName%')
            .limit(1)
            .single();

        if (response != null) {
          final location = response['location'] as Map<String, dynamic>?;
          final coordinates = location?['coordinates'] as List?;
            
            return {
            'id': response['id'],
            'name': response['name'],
            'address': response['address'],
            'latitude': coordinates != null ? coordinates[1] : null,
            'longitude': coordinates != null ? coordinates[0] : null,
            'venue_type': 'cinema'
          };
        }
      } else {
        // Default to searching theatres
        final response = await _supabase
            .from('theatres')
            .select('''
              place_id,
              name,
              address,
              location
            ''')
            .ilike('name', '%$venueName%')
            .limit(1)
            .single();

        if (response != null) {
          final location = response['location'] as Map<String, dynamic>?;
          final coordinates = location?['coordinates'] as List?;
          
          return {
            'id': response['place_id'],
            'name': response['name'],
            'address': response['address'],
            'latitude': coordinates != null ? coordinates[1] : null,
            'longitude': coordinates != null ? coordinates[0] : null,
            'venue_type': 'theatre'
          };
        }
      }
      
      return null;
    } catch (e) {
      print('Error finding venue location: $e');
      return null;
    }
  }

  String _getAreaFromCoordinates(double lat, double lon) {
    // Define area boundaries
    final areas = {
      'Covent Garden': {'lat': 51.5117, 'lon': -0.1240, 'radius': 0.5},
      'Soho': {'lat': 51.5137, 'lon': -0.1337, 'radius': 0.5},
      'Piccadilly Circus': {'lat': 51.5101, 'lon': -0.1344, 'radius': 0.5},
      'Leicester Square': {'lat': 51.5111, 'lon': -0.1281, 'radius': 0.5},
    };

    // Find closest area
    String closestArea = 'Central London';
    double minDistance = double.infinity;

    areas.forEach((areaName, coords) {
      final distance = calculateDistance(
        lat, lon,
        coords['lat']!, coords['lon']!
      );
      if (distance < minDistance && distance < (coords['radius']! * 1000)) {
        minDistance = distance;
        closestArea = areaName;
      }
    });

    return closestArea;
  }

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

  Future<List<String>> _getGroupIds(List<String> groupMentions) async {
    if (groupMentions.isEmpty) return [];
    
    try {
      final groups = await _supabase
          .from('groups')
          .select('id, name')
          .inFilter('name', groupMentions);
      
      return (groups as List).map((g) => g['id'].toString()).toList();
    } catch (e) {
      print('Error getting group IDs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRestaurantsByFeatures(String query) async {
    try {
      final completion = await OpenAI.instance.chat.create(
        model: dotenv.env['OPENAI_MODEL_ID'] ?? "ft:gpt-3.5-turbo-0125:personal::AjMYeMJb",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                """Match the user's query to these restaurant features and return a JSON object with boolean values:
                Features:
                - Dog_Friendly: allows dogs
                - Business_Meals: suitable for business meetings
                - Birthdays: good for birthday celebrations
                - Date Nights: romantic or date spots
                - Pre_Theatre: suitable for pre-theatre dining
                - Cheap_Eat: affordable dining
                - Fine_Dining: upscale dining experience
                - kids: child-friendly
                - solo: comfortable for solo diners
                - Bar: has a good bar/drinks
                - Casual_Dinner: good for casual dining
                - Brunch: serves brunch
                - Vegetarian: good vegetarian options
                - Vegan: good vegan options
                - Breakfast: serves breakfast
                - Lunch: serves lunch
                - Dinner: serves dinner"""
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(query)],
          ),
        ],
      );

      final responseContent = completion.choices.first.message.content?.firstOrNull?.text ?? '{}';
      final features = json.decode(responseContent) as Map<String, dynamic>;

      final conditions = features.entries
          .where((e) => e.value == true)
          .map((e) => e.key.trim())
          .toList();

      if (conditions.isEmpty) return [];

      // Use a simpler query structure
      final response = await _supabase
          .from('restaurants')
          .select('*, restaurants_features(*)')
          .eq('restaurants_features.${conditions[0]}', true)
          .limit(10);

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('Error matching restaurant features: $e');
      return [];
    }
  }

  Future<Map<String, double>?> getAreaCoordinates(String areaName) async {
    try {
      final response = await _supabase
          .from('london_areas')
          .select('latitude, longitude')
          .ilike('name', '%$areaName%')
          .limit(1);

      if (response != null && response.isNotEmpty) {
        print('Found coordinates for $areaName: ${response.first}');
        return {
          'lat': response.first['latitude'] as double,
          'lon': response.first['longitude'] as double,
        };
      }

      // If no area found, try to get coordinates from theatres
      final theatres = await _supabase
          .from('theatres')
          .select()
          .ilike('name', '%$areaName%')
          .limit(1);

      if (theatres != null && theatres.isNotEmpty) {
        print('Using coordinates from theatre in $areaName');
        return {
          'lat': theatres.first['latitude'] as double,
          'lon': theatres.first['longitude'] as double,
        };
      }

      print('No coordinates found for $areaName, using default Covent Garden location');
      return {
        'lat': 51.5117,
        'lon': -0.1240
      };
    } catch (e) {
      print('Error getting area coordinates for $areaName: $e');
      // Return default Covent Garden coordinates as fallback
      return {
        'lat': 51.5117,
        'lon': -0.1240
      };
    }
  }

  Future<void> _debugPrintRestaurantFeatures() async {
    try {
      // First check the table name
      final tables = await _supabase
          .from('information_schema.tables')
          .select('table_name')
          .eq('table_schema', 'public');
      print('Available tables: $tables');

      // Try both possible table names
      try {
        final result1 = await _supabase
            .from('restaurant_features')
            .select('*')
            .limit(1);
        print('restaurant_features sample: $result1');
      } catch (e) {
        print('Error with restaurant_features: $e');
      }

      try {
        final result2 = await _supabase
            .from('restaurants_features')
            .select('*')
            .limit(1);
        print('restaurants_features sample: $result2');
      } catch (e) {
        print('Error with restaurants_features: $e');
      }

      // Also try to get column names
      final columns = await _supabase
          .from('information_schema.columns')
          .select('column_name, table_name')
          .eq('table_schema', 'public')
          .inFilter('table_name', ['restaurant_features', 'restaurants_features']);
      print('Available columns: $columns');

    } catch (e) {
      print('Error checking features: $e');
    }
  }

  Future<List<String>> _getCombinedDietaryRequirements(List<String> userEmails) async {
    List<String> excludeCuisineTypes = [];
    
    try {
      // Get dietary requirements for all mentioned users
      final dietaryPrefs = await _supabase
          .from('user_dietary_requirements')
          .select('no_beef, no_pork, vegetarian, vegan, halal, kosher')
          .inFilter('user_id', userEmails);

      // Combine all dietary restrictions
      for (var prefs in dietaryPrefs) {
        if (prefs['no_beef'] == true) {
          excludeCuisineTypes.addAll(['Steakhouse', 'American Steakhouse', 'Brazilian Steakhouse', 'Argentinian Steakhouse']);
        }
        if (prefs['no_pork'] == true) {
          excludeCuisineTypes.addAll(['BBQ', 'American BBQ', 'Korean BBQ', 'Brazilian BBQ']);
        }
        if (prefs['vegetarian'] == true) {
          excludeCuisineTypes.addAll(['Steakhouse', 'BBQ', 'American BBQ', 'Korean BBQ', 'Brazilian BBQ']);
        }
        if (prefs['vegan'] == true) {
          excludeCuisineTypes.addAll(['Steakhouse', 'BBQ', 'Seafood', 'Fish & Chips']);
        }
        if (prefs['halal'] == true || prefs['kosher'] == true) {
          excludeCuisineTypes.addAll(['BBQ', 'American BBQ', 'Pub Food']);
        }
      }
    } catch (e) {
      print('Error getting combined dietary requirements: $e');
    }
    
    // Remove duplicates
    return excludeCuisineTypes.toSet().toList();
  }

  Future<List<String>> _getCombinedExcludedCuisines(List<String> userEmails) async {
    final Set<String> excludedCuisines = {};
    
    try {
      final userPrefs = await _supabase
          .from('profiles')
          .select('excluded_cuisines')
          .inFilter('email', userEmails);

      for (var prefs in userPrefs) {
        if (prefs['excluded_cuisines'] != null) {
          excludedCuisines.addAll(List<String>.from(prefs['excluded_cuisines']));
        }
      }
    } catch (e) {
      print('Error getting combined excluded cuisines: $e');
    }
    
    return excludedCuisines.toList();
  }

  Future<Map<String, dynamic>> getGroupPreferences(String groupId) async {
    try {
      // Get the group and its members
      final group = await _supabase
          .from('groups')
          .select()
          .eq('id', groupId)
          .single();

      final memberIds = List<String>.from(group['member_ids'] ?? []);

      // Get all members' dietary requirements
      final dietaryRequirements = await _supabase
          .from('profiles')
          .select('dietary_requirements')
          .inFilter('id', memberIds);

      // Get all members' excluded cuisines
      final excludedCuisines = await _supabase
          .from('profiles')
          .select('excluded_cuisines')
          .inFilter('id', memberIds);

      // Get all members' restaurant preferences
      final restaurantPreferences = await _supabase
          .from('profiles')
          .select('restaurant_preferences')
          .inFilter('id', memberIds);

      // Combine all preferences
      return {
        'dietary_requirements': _combineDietaryRequirements(dietaryRequirements),
        'excluded_cuisines': _combineExcludedCuisines(excludedCuisines),
        'restaurant_preferences': _combineRestaurantPreferences(restaurantPreferences),
      };
    } catch (e) {
      print('Error getting group preferences: $e');
      return {};
    }
  }

  Map<String, bool> _combineDietaryRequirements(List<dynamic> requirements) {
    final combined = <String, bool>{};
    for (var req in requirements) {
      if (req['dietary_requirements'] != null) {
        for (var diet in req['dietary_requirements']) {
          // If any member has a dietary requirement, include it
          combined[diet] = true;
        }
      }
    }
    return combined;
  }

  Set<String> _combineExcludedCuisines(List<dynamic> exclusions) {
    final combined = <String>{};
    for (var exc in exclusions) {
      if (exc['excluded_cuisines'] != null) {
        combined.addAll(List<String>.from(exc['excluded_cuisines']));
      }
    }
    return combined;
  }

  Map<String, bool> _combineRestaurantPreferences(List<dynamic> preferences) {
    final combined = <String, bool>{};
    for (var pref in preferences) {
      if (pref['restaurant_preferences'] != null) {
        for (var feature in pref['restaurant_preferences']) {
          // If any member wants a feature, include it
          combined[feature] = true;
        }
      }
    }
    return combined;
  }

  Map<String, dynamic> _combineUserAndGroupPreferences(
    Map<String, dynamic> userPrefs,
    Map<String, dynamic> groupPrefs,
  ) {
    // Convert Sets to Lists and ensure all values are JSON-encodable
    return {
      'dietary_requirements': Map<String, bool>.from(
        {...?groupPrefs['dietary_requirements'], ...?userPrefs['dietary_requirements']}
      ),
      'excluded_cuisines': List<String>.from([
        ...?groupPrefs['excluded_cuisines'],
        ...?userPrefs['excluded_cuisines'],
      ]),
      'restaurant_preferences': Map<String, bool>.from(
        {...?groupPrefs['restaurant_preferences'], ...?userPrefs['restaurant_preferences']}
      ),
    };
  }

  Future<List<Map<String, dynamic>>> searchRestaurants({
    required String searchTerm,
    List<String>? groupIds,
    Map<String, dynamic>? userPreferences,
  }) async {
    try {
      print('\n=== Starting Restaurant Search ===');
      print('Initial search term: $searchTerm');

      // Process the search query first
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's preferences if not provided
      if (userPreferences == null) {
        final userProfile = await _supabase
            .from('profiles')
            .select('dietary_requirements, excluded_cuisines, restaurant_preferences')
            .eq('id', userId)
            .single();
        
        userPreferences = {
          'dietary_requirements': userProfile['dietary_requirements'] ?? {},
          'excluded_cuisines': userProfile['excluded_cuisines'] ?? [],
          'restaurant_preferences': userProfile['restaurant_preferences'] ?? {},
        };
        print('Current user preferences: $userPreferences');
      }
      
      final processedQuery = await processSearchQuery(searchTerm, userId);
      print('Processed query: $processedQuery');

      // Get user and group preferences
      Map<String, dynamic> groupPreferences = {};
      if (groupIds != null && groupIds.isNotEmpty) {
        groupPreferences = await _getGroupPreferences(groupIds);
      }

      // Combine user and group preferences
      final combinedPreferences = _combineUserAndGroupPreferences(
        userPreferences,
        groupPreferences,
      );

      print('Combined preferences: $combinedPreferences');

      // Get venue details from processed query
      Map<String, dynamic>? venue = processedQuery['venue_details'] as Map<String, dynamic>?;
      String? cuisineType = processedQuery['cuisine_type'] as String?;

      print('Using venue: ${venue?['name']}');
      print('Using cuisine type: $cuisineType');

      // Build the query
      var query = _supabase
          .from('restaurants')
          .select();

      // Apply cuisine filter if specified
      if (cuisineType != null && cuisineType.isNotEmpty) {
        query = query.ilike('CuisineType', '%$cuisineType%');
      }

      // If we have venue coordinates, use the find_nearby_restaurants function
      if (venue != null && venue['latitude'] != null && venue['longitude'] != null) {
        final response = await _supabase.rpc(
          'find_nearby_restaurants',
          params: {
            'ref_latitude': venue['latitude'],
            'ref_longitude': venue['longitude'],
            'search_cuisine_type': cuisineType ?? '',
            'max_distance': 2000 // 2km radius
          }
        );
        print('Found ${response.length} nearby restaurants');
        return List<Map<String, dynamic>>.from(response);
      }

      // Fallback to regular search if no venue coordinates
      final List<dynamic> response = await query;
      print('Found ${response.length} restaurants before applying preferences');

      // Convert to the expected format and calculate distances
      var results = response.map((row) {
        final restaurantLat = row['Latitude'] as double?;
        final restaurantLon = row['Longitude'] as double?;
        double? distance;

        if (venue != null && restaurantLat != null && restaurantLon != null) {
          distance = calculateDistance(
            venue['latitude'] as double,
            venue['longitude'] as double,
            restaurantLat,
            restaurantLon
          );
        }

        return {
          'RestaurantID': row['RestaurantID'],
          'Name': row['Name'],
          'CuisineType': row['CuisineType'],
          'Address': row['Address'],
          'Rating': row['Rating'],
          'PriceLevel': row['PriceLevel'],
          'Latitude': restaurantLat,
          'Longitude': restaurantLon,
          'Distance': distance,
        };
      }).toList();

      // Apply user preferences filtering
      final excludedCuisines = List<String>.from(combinedPreferences['excluded_cuisines'] ?? []);
      if (excludedCuisines.isNotEmpty) {
        print('Excluding cuisines: $excludedCuisines');
        results = results.where((r) {
          final cuisine = (r['CuisineType'] as String?) ?? '';
          return !excludedCuisines.any((excluded) => 
            cuisine.toLowerCase().contains(excluded.toLowerCase())
          );
        }).toList();
      }

      // Apply dietary requirements if any
      final dietaryRequirements = Map<String, bool>.from(combinedPreferences['dietary_requirements'] ?? {});
      if (dietaryRequirements.isNotEmpty) {
        print('Applying dietary requirements: $dietaryRequirements');
        if (dietaryRequirements['vegetarian'] == true) {
          results = results.where((r) {
            final cuisine = (r['CuisineType'] as String?) ?? '';
            return !['steakhouse', 'bbq', 'brazilian bbq', 'korean bbq'].any(
              (meat) => cuisine.toLowerCase().contains(meat)
            );
          }).toList();
        }
        if (dietaryRequirements['vegan'] == true) {
          results = results.where((r) {
            final cuisine = (r['CuisineType'] as String?) ?? '';
            return !['steakhouse', 'bbq', 'seafood', 'fish'].any(
              (nonVegan) => cuisine.toLowerCase().contains(nonVegan)
            );
          }).toList();
        }
        // Add more dietary filters as needed
      }

      print('Found ${results.length} restaurants after applying preferences');

      // Sort by distance if we have a venue, otherwise by rating
      if (venue != null) {
        results.sort((a, b) => 
          ((a['Distance'] ?? double.infinity)
          .compareTo(b['Distance'] ?? double.infinity))
        );

        // Filter to only show restaurants within 2km
        return results.where((r) => (r['Distance'] ?? double.infinity) <= 2000).toList();
      } else {
        results.sort((a, b) => 
          ((b['Rating'] ?? 0) as num).compareTo((a['Rating'] ?? 0) as num)
        );
        return results;
      }
    } catch (e) {
      print('Error searching restaurants: $e');
      return [];
    }
  }

  Map<String, dynamic> _getLocationParams(double lat, double lon) {
    return {
      'p_latitude': lat,
      'p_longitude': lon,
      'p_radius': 2000.0, // 2km radius
    };
  }

  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    try {
      final response = await _supabase
          .from('groups')
          .select('''
            id,
            name,
            created_by,
            member_ids,
            created_at
          ''')
          .or('created_by.eq.$userId,member_ids.cs.{$userId}')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((group) {
        return {
          'id': group['id'],
          'name': group['name'],
          'is_owner': group['created_by'] == userId,
          'member_count': (group['member_ids'] as List).length,
        };
      }).toList();
    } catch (e) {
      print('Error getting user groups: $e');
      return [];
    }
  }

  Future<List<String>> _validateAndGetGroupIds(
    List<String> groupMentions,
    List<Map<String, dynamic>> userGroups
  ) async {
    // Filter mentions to only include groups the user has access to
    final validGroupIds = groupMentions
        .map((mention) => userGroups.firstWhere(
            (g) => g['name'].toLowerCase() == mention.toLowerCase(),
            orElse: () => {'id': null}
          )['id'])
        .where((id) => id != null)
        .cast<String>()
        .toList();

    return validGroupIds;
  }

  Future<Map<String, dynamic>> _getGroupPreferences(List<String> groupIds) async {
    try {
      final allGroupPreferences = await Future.wait(
        groupIds.map((id) => getGroupPreferences(id))
      );
      
      return allGroupPreferences.fold<Map<String, dynamic>>(
        {},
        (combined, prefs) => _combineUserAndGroupPreferences(combined, prefs),
      );
    } catch (e) {
      print('Error getting group preferences: $e');
      return {};
    }
  }
} 