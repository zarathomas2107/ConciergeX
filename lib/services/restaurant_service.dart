import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:typed_data';

class SearchResponse {
  final List<Restaurant> restaurants;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? datetime;
  final double? venueLat;
  final double? venueLon;

  SearchResponse({
    required this.restaurants,
    this.preferences,
    this.location,
    this.datetime,
    this.venueLat,
    this.venueLon,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      restaurants: (json['restaurants'] as List<dynamic>)
          .map((r) => Restaurant.fromJson(r as Map<String, dynamic>))
          .toList(),
      preferences: json['preferences'] as Map<String, dynamic>?,
      location: json['location'] as Map<String, dynamic>?,
      datetime: json['datetime'] as Map<String, dynamic>?,
      venueLat: json['venue_lat'] as double?,
      venueLon: json['venue_lon'] as double?,
    );
  }
}

class RestaurantService {
  final _supabase = Supabase.instance.client;
  final _serviceClient = SupabaseClient(
    dotenv.env['SUPABASE_URL'] ?? '',
    dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '',
  );
  final String _baseUrl = 'https://restaurant-search-api-378538476539.europe-west2.run.app';

  // Add getter for Supabase client
  SupabaseClient get supabase => _supabase;
  
  // Add getter for service client
  SupabaseClient get serviceClient => _serviceClient;

  Future<SearchResponse> searchWithAgent(String query, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'query': query,
          'user_id': userId
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get search parameters from LLM: ${response.statusCode}');
      }

      final searchParams = json.decode(response.body);
      debugPrint('LLM Response: $searchParams');
      
      final location = searchParams['location'];
      String refPoint;
      Map<String, dynamic>? venueResponse;
      
      if (location == null || location['id'] == null) {
        throw Exception('No location data found in API response');
      }

      final locationId = location['id'] as String;

      try {
        venueResponse = await _serviceClient
            .from('points_of_interest')
            .select('latitude, longitude')
            .eq('id', locationId)
            .single();
        
        refPoint = 'POINT(${venueResponse['longitude']} ${venueResponse['latitude']})';
      } catch (e) {
        throw Exception('Failed to get location coordinates from POI table');
      }

      final requiredCuisines = (searchParams['required_cuisines'] as List<dynamic>?)
          ?.where((cuisine) => cuisine != null && cuisine.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList() ?? [];

      final excludedCuisines = (searchParams['excluded_cuisines'] as List<dynamic>?)
          ?.where((cuisine) => cuisine != null && cuisine.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList() ?? [];

      final dietaryRequirements = (searchParams['dietary_requirements'] as List<dynamic>?)
          ?.where((requirement) => requirement != null && requirement.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList() ?? [];

      final data = await _serviceClient.rpc(
        'get_restaurants_within_distance_v4',
        params: {
          'ref_point': refPoint,
          'max_distance': 5000.0,
          'excluded_cuisines': excludedCuisines,
          'required_cuisines': requiredCuisines,
          'start_date_str': searchParams['datetime']['start_date'],
          'end_date_str': searchParams['datetime']['end_date'],
          'start_time_str': '${searchParams['datetime']['start_time']}:00',
          'end_time_str': '${searchParams['datetime']['end_time']}:00',
        },
      );

      if (data == null) {
        return SearchResponse(
          restaurants: [],
          preferences: searchParams['preferences'],
          location: searchParams['location'],
          datetime: searchParams['datetime'],
          venueLat: venueResponse?['latitude'],
          venueLon: venueResponse?['longitude'],
        );
      }

      final restaurants = (data as List<dynamic>)
          .map((data) => Restaurant.fromJson(data))
          .where((restaurant) {
            return !restaurant.cuisineTypes.any((cuisine) => 
              excludedCuisines.any((excluded) => 
                cuisine.toLowerCase().contains(excluded.toLowerCase())
              )
            );
          })
          .toList();

      return SearchResponse(
        restaurants: restaurants,
        preferences: searchParams['preferences'],
        location: searchParams['location'],
        datetime: searchParams['datetime'],
        venueLat: venueResponse?['latitude'],
        venueLon: venueResponse?['longitude'],
      );
    } catch (e) {
      return SearchResponse(
        restaurants: [],
        preferences: null,
        location: null,
        datetime: null,
        venueLat: null,
        venueLon: null,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableGroups(String userId) async {
    try {
      final response = await _supabase
          .rpc('get_group_members_preferences', params: {
            'user_id': userId
          });
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map) {
        // If response is a Map with data field
        final data = response['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      
      // Return empty list if response format is unexpected
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error getting available groups: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<SearchResponse> searchRestaurants(String query) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return searchWithAgent(query, userId);
  }

  Future<List<Restaurant>> getRestaurantsNearVenue(
    String venueName,
    double maxDistance,
    List<String> excludedCuisines,
    DateTime startDate,
    DateTime endDate,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) async {
    try {
      // Use central London coordinates (Covent Garden)
      const refPoint = 'POINT(-0.1240 51.5117)';

      // Format dates in YYYY-MM-DD format
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
      
      // Format times in HH24:MI:SS format
      final startTimeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
      final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

      final response = await _serviceClient.rpc(
        'get_restaurants_within_distance_v4',
        params: {
          'ref_point': refPoint,
          'max_distance': maxDistance,
          'excluded_cuisines': excludedCuisines,
          'start_date_str': startDateStr,
          'end_date_str': endDateStr,
          'start_time_str': startTimeStr,
          'end_time_str': endTimeStr,
        },
      );

      if (response == null) return [];

      return (response as List)
          .map((data) => Restaurant.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error getting restaurants near venue: $e');
      return [];
    }
  }

  // Helper method to convert hex string to double
  double _hexToDouble(String hex) {
    try {
      // Convert hex to bytes
      final bytes = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      
      // Reverse bytes for little-endian
      final reversed = bytes.reversed.toList();
      
      // Convert to binary string
      final binary = reversed.map((b) => b.toRadixString(2).padLeft(8, '0')).join();
      
      // Parse IEEE 754 double
      final sign = binary[0] == '1' ? -1 : 1;
      final exponent = int.parse(binary.substring(1, 12), radix: 2) - 1023;
      final fraction = binary.substring(12).split('').fold<double>(0, (sum, bit) {
        return sum + (bit == '1' ? 1 / pow(2, binary.substring(12).indexOf(bit) + 1) : 0);
      });
      
      final result = sign * (1 + fraction) * pow(2, exponent);
      return result;
    } catch (e) {
      return 0.0;
    }
  }
} 