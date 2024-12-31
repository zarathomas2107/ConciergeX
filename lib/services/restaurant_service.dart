import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';

class RestaurantService {
  final SupabaseClient _supabaseClient;

  RestaurantService() : _supabaseClient = Supabase.instance.client;

  Future<List<Restaurant>> searchWithParams(Map<String, dynamic> params) async {
    try {
      print('=== START RESTAURANT SEARCH ===');
      print('Searching with params: $params');

      // Get theatre details first
      final List<dynamic> theatreResponse = await _supabaseClient
          .from('theatre_details')
          .select()
          .eq('name', 'Apollo Theatre');  // Or use params['theatre_name'] if available

      if (theatreResponse.isEmpty) {
        throw Exception('Theatre not found');
      }

      final theatre = theatreResponse.first;
      final theatreLat = theatre['latitude'] as double;
      final theatreLng = theatre['longitude'] as double;

      // Then query restaurants near the theatre
      var restaurantsQuery = _supabaseClient
          .from('restaurants')
          .select();

      if (params.containsKey('cuisine_type') && params['cuisine_type'].isNotEmpty) {
        restaurantsQuery = restaurantsQuery.ilike('CuisineType', '%${params['cuisine_type']}%');
      }

      final List<dynamic> restaurants = await restaurantsQuery;
      print('Found ${restaurants.length} restaurants');

      List<Restaurant> results = [];
      for (var row in restaurants) {
        try {
          final restaurantId = row['RestaurantID']?.toString() ?? '';
          print('\nProcessing ${row['Name']}:');
          
          // Get availability data
          final List<dynamic> availabilityResponse = await _supabaseClient
              .from('restaurants_availability')
              .select()
              .eq('RestaurantID', restaurantId)
              .eq('is_available', true);

          // Process availability data
          Set<String> uniqueDates = {};
          Map<String, List<String>> timeSlots = {};
          
          for (var slot in availabilityResponse) {
            String slotDate = slot['date']?.toString() ?? '';
            String slotTime = slot['time_slot']?.toString() ?? '';
            if (slotDate.isNotEmpty) {
              uniqueDates.add(slotDate);
              timeSlots[slotDate] ??= [];
              if (slotTime.isNotEmpty) {
                timeSlots[slotDate]!.add(slotTime);
              }
            }
          }

          List<String> sortedDates = uniqueDates.toList()..sort();

          // Create restaurant object with the new parameter names
          final restaurant = Restaurant(
            restaurantId: restaurantId,
            name: row['Name']?.toString() ?? '',
            cuisineType: row['CuisineType']?.toString() ?? '',
            photoUrl: 'https://snxksagtvimkrngjueal.supabase.co/storage/v1/object/public/Photos/London_Restaurant_Photos/$restaurantId.jpg',
            rating: row['Rating'] != null ? double.tryParse(row['Rating'].toString()) ?? 0.0 : 0.0,
            priceLevel: row['PriceLevel'] != null && row['PriceLevel'] != -1 
                ? int.tryParse(row['PriceLevel'].toString()) ?? 1 
                : 1,
            address: row['Address']?.toString() ?? '',
            dates: sortedDates,
            times: timeSlots,
            showAvailability: true,
            hasAvailability: sortedDates.isNotEmpty,
            firstAvailableDate: sortedDates.isNotEmpty ? sortedDates.first : null,
            firstAvailableTime: sortedDates.isNotEmpty && timeSlots[sortedDates.first]?.isNotEmpty == true 
                ? timeSlots[sortedDates.first]!.first 
                : null,
            distanceInMeters: 0.0,
            latitude: row['Latitude'] != null ? double.tryParse(row['Latitude'].toString()) ?? 0.0 : 0.0,
            longitude: row['Longitude'] != null ? double.tryParse(row['Longitude'].toString()) ?? 0.0 : 0.0,
          );
          
          results.add(restaurant);
        } catch (e) {
          print('Error processing restaurant ${row['Name']}: $e');
        }
      }

      print('\n=== FINISHED RESTAURANT SEARCH ===');
      print('Processed ${results.length} restaurants');
      return results;

    } catch (e, stackTrace) {
      print('Error querying Supabase: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Restaurant>> findNearbyRestaurants({
    required double latitude,
    required double longitude,
    double radiusInMeters = 5000, // Default 5km radius
  }) async {
    try {
      print('Searching for restaurants near ($latitude, $longitude) within $radiusInMeters meters');

      final response = await _supabaseClient
          .rpc('find_nearby_restaurants', params: {
            'lat': latitude,
            'long': longitude,
            'radius_meters': radiusInMeters,
          });

      print('Found ${response.length} nearby restaurants');

      List<Restaurant> results = [];
      for (var row in response) {
        try {
          final restaurantId = row['RestaurantID']?.toString() ?? '';
          final distance = row['distance']?.toString() ?? '';
          print('\nProcessing restaurant: ${row['Name']} (${distance}m away)');
          
          // Get availability data
          final List<dynamic> availabilityResponse = await _supabaseClient
              .from('restaurants_availability')
              .select()
              .eq('RestaurantID', restaurantId)
              .eq('is_available', true);

          Set<String> uniqueDates = {};
          Map<String, List<String>> timeSlots = {};
          
          for (var slot in availabilityResponse) {
            String slotDate = slot['date']?.toString() ?? '';
            String slotTime = slot['time_slot']?.toString() ?? '';
            if (slotDate.isNotEmpty) {
              uniqueDates.add(slotDate);
              timeSlots[slotDate] ??= [];
              if (slotTime.isNotEmpty) {
                timeSlots[slotDate]!.add(slotTime);
              }
            }
          }

          List<String> sortedDates = uniqueDates.toList()..sort();

          final restaurant = Restaurant(
            restaurantId: restaurantId,
            name: row['Name']?.toString() ?? '',
            cuisineType: row['CuisineType']?.toString() ?? '',
            photoUrl: 'https://snxksagtvimkrngjueal.supabase.co/storage/v1/object/public/Photos/London_Restaurant_Photos/$restaurantId.jpg',
            rating: row['Rating'] != null ? double.tryParse(row['Rating'].toString()) ?? 0.0 : 0.0,
            priceLevel: row['PriceLevel'] != null && row['PriceLevel'] != -1 
                ? int.tryParse(row['PriceLevel'].toString()) ?? 1 
                : 1,
            address: row['Address']?.toString() ?? '',
            dates: sortedDates,
            times: timeSlots,
            showAvailability: false,
            hasAvailability: sortedDates.isNotEmpty,
            firstAvailableDate: sortedDates.isNotEmpty ? sortedDates.first : null,
            firstAvailableTime: sortedDates.isNotEmpty && timeSlots[sortedDates.first]?.isNotEmpty == true 
                ? timeSlots[sortedDates.first]!.first 
                : null,
            distanceInMeters: double.tryParse(distance) ?? 0.0,
            latitude: row['Latitude'] != null ? double.tryParse(row['Latitude'].toString()) ?? 0.0 : 0.0,
            longitude: row['Longitude'] != null ? double.tryParse(row['Longitude'].toString()) ?? 0.0 : 0.0,
          );
          
          results.add(restaurant);
        } catch (e) {
          print('Error processing restaurant ${row['Name']}: $e');
        }
      }

      return results;

    } catch (e, stackTrace) {
      print('Error finding nearby restaurants: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Restaurant>> findRestaurantsNearTheatre(String theatreName, String? cuisineType) async {
    try {
      print('Looking for ${cuisineType ?? 'any'} cuisine near $theatreName');

      final theatreResponse = await _supabaseClient
          .from('theatre_details')
          .select()
          .eq('name', theatreName)
          .limit(1);

      if (theatreResponse.isEmpty) {
        final allTheatres = await _supabaseClient
            .from('theatre_details')
            .select('name')
            .order('name');
        
        throw Exception('''
Theatre not found: "$theatreName"
Available theatres:
${allTheatres.map((t) => '- ${t['name']}').join('\n')}
''');
      }

      final theatre = theatreResponse.first;
      final theatreLat = theatre['latitude'] as double;
      final theatreLng = theatre['longitude'] as double;
      final exactName = theatre['name'] as String;

      print('Found theatre: $exactName at coordinates: $theatreLat, $theatreLng');

      // Then find restaurants near those coordinates
      final response = await _supabaseClient
          .rpc('find_restaurants_near_coordinates', params: {
            'ref_latitude': theatreLat,
            'ref_longitude': theatreLng,
            'search_cuisine_type': cuisineType ?? '',
            'max_distance': 1000
          });

      final restaurants = (response as List)
          .map((data) => Restaurant.fromJson(data as Map<String, dynamic>))
          .toList();

      print('Found ${restaurants.length} restaurants near $exactName');
      return restaurants;

    } catch (e, stackTrace) {
      print('Error: $e');
      print('Stack trace: $stackTrace');
      throw e;
    }
  }

  Future<List<Restaurant>> applyFilters(
    List<Restaurant> restaurants,
    Map<String, dynamic> params,
  ) async {
    try {
      // Start with the existing restaurants list
      List<Restaurant> filteredResults = List.from(restaurants);

      // Apply cuisine filter if specified
      if (params.containsKey('cuisine_type') && params['cuisine_type'].isNotEmpty) {
        filteredResults = filteredResults.where((r) => 
          r.cuisineType.toLowerCase().contains(params['cuisine_type'].toLowerCase())
        ).toList();
      }

      // Apply price level filter
      if (params.containsKey('price_level')) {
        final priceLevel = int.tryParse(params['price_level'].toString());
        if (priceLevel != null) {
          filteredResults = filteredResults.where((r) => 
            r.priceLevel <= priceLevel
          ).toList();
        }
      }

      // Apply rating filter
      if (params.containsKey('min_rating')) {
        final minRating = double.tryParse(params['min_rating'].toString());
        if (minRating != null) {
          filteredResults = filteredResults.where((r) => 
            r.rating >= minRating
          ).toList();
        }
      }

      // Apply timing constraints for pre/post show dining
      if (params.containsKey('timing')) {
        final timing = params['timing'];
        final showTime = params['show_time'];
        
        if (timing == 'pre_show' && showTime != null) {
          filteredResults = filteredResults.where((r) {
            if (r.times.isEmpty) return false;
            
            try {
              final showDateTime = DateTime.parse(showTime);
              final latestDiningStart = showDateTime.subtract(const Duration(minutes: 90));
              
              for (var date in r.dates) {
                final slots = r.times[date] ?? [];
                for (var slot in slots) {
                  final slotTime = DateTime.parse('$date $slot');
                  if (slotTime.isBefore(latestDiningStart)) {
                    return true;
                  }
                }
              }
            } catch (e) {
              print('Error parsing show time: $e');
            }
            return false;
          }).toList();
        }
      }

      // Sort results based on multiple criteria
      filteredResults.sort((a, b) {
        // Prioritize distance if we're searching near a venue
        int distanceCompare = a.distanceInMeters.compareTo(b.distanceInMeters);
        if (distanceCompare != 0) return distanceCompare;

        // Then consider rating
        int ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;

        // Finally, sort by price (cheaper first if not specified otherwise)
        return a.priceLevel.compareTo(b.priceLevel);
      });

      return filteredResults;

    } catch (e) {
      print('Error applying filters: $e');
      return restaurants;  // Return original list if filtering fails
    }
  }
} 