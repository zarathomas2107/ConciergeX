import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'package:flutter/material.dart';

class SearchResponse {
  final List<Restaurant> restaurants;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? datetime;

  SearchResponse({
    required this.restaurants,
    this.preferences,
    this.location,
    this.datetime,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      restaurants: (json['restaurants'] as List<dynamic>)
          .map((r) => Restaurant.fromJson(r as Map<String, dynamic>))
          .toList(),
      preferences: json['preferences'] as Map<String, dynamic>?,
      location: json['location'] as Map<String, dynamic>?,
      datetime: json['datetime'] as Map<String, dynamic>?,
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
      // Get search parameters from LLM
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        throw Exception('OPENAI_API_KEY not found in environment');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey'
        },
        body: json.encode({
          'query': query,
          'user_id': userId
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('LLM API error: ${response.body}');
        throw Exception('Failed to get search parameters from LLM: ${response.statusCode}');
      }

      final searchParams = json.decode(response.body);
      debugPrint('LLM search params: $searchParams');

      // Get coordinates from points_of_interest table using venue ID
      final venueId = searchParams['location']['id'] as String;
      final venueResponse = await _serviceClient
          .from('points_of_interest')
          .select('latitude, longitude')
          .eq('id', venueId)
          .single();
      
      final refPoint = 'POINT(${venueResponse['longitude']} ${venueResponse['latitude']})';
      debugPrint('Venue coordinates: $refPoint');

      // Get required cuisines from search params, if any specific restaurants were requested
      final requiredCuisines = (searchParams['required_cuisines'] as List<dynamic>?)
          ?.where((cuisine) => cuisine != null && cuisine.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList() ?? [];
      debugPrint('Required cuisines: $requiredCuisines');

      // Get excluded cuisines - these should always be applied
      final excludedCuisines = (searchParams['excluded_cuisines'] as List<dynamic>?)
          ?.where((cuisine) => cuisine != null && cuisine.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList() ?? [];
      debugPrint('Excluded cuisines: $excludedCuisines');

      // Get dietary requirements
      final dietaryRequirements = (searchParams['dietary_requirements'] as List<dynamic>?)
          ?.where((requirement) => requirement != null && requirement.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList() ?? [];
      debugPrint('Dietary requirements: $dietaryRequirements');

      // Debug print to log RPC parameters
      debugPrint('RPC Parameters:');
      debugPrint('ref_point: $refPoint');
      debugPrint('max_distance: 5000.0');
      debugPrint('excluded_cuisines: $excludedCuisines');
      debugPrint('required_cuisines: $requiredCuisines');
      debugPrint('start_date: ${searchParams['datetime']['start_date']}');
      debugPrint('end_date: ${searchParams['datetime']['end_date']}');
      debugPrint('start_time: ${searchParams['datetime']['start_time']}:00');
      debugPrint('end_time: ${searchParams['datetime']['end_time']}:00');

      final data = await _serviceClient.rpc(
        'get_restaurants_within_distance_v2',
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

      debugPrint('$data');

      if (data == null) {
        return SearchResponse(
          restaurants: [],
          preferences: searchParams['preferences'],
          location: searchParams['location'],
          datetime: searchParams['datetime'],
        );
      }

      // Convert restaurants and apply excluded cuisines filter
      final restaurants = (data as List<dynamic>)
          .map((data) => Restaurant.fromJson(data))
          .where((restaurant) {
            // Always apply excluded cuisines filter
            return !restaurant.cuisineTypes.any((cuisine) => 
              excludedCuisines.any((excluded) => 
                cuisine.toLowerCase().contains(excluded.toLowerCase())
              )
            );
          })
          .toList();

      debugPrint('Found ${restaurants.length} restaurants after cuisine filtering');

      return SearchResponse(
        restaurants: restaurants,
        preferences: searchParams['preferences'],
        location: searchParams['location'],
        datetime: searchParams['datetime'],
      );
    } catch (e) {
      debugPrint('Error in searchWithAgent: $e');
      return SearchResponse(
        restaurants: [],
        preferences: null,
        location: null,
        datetime: null,
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
      debugPrint('Unexpected response format: $response');
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

      debugPrint('Querying restaurants with params:');
      debugPrint('  ref_point: $refPoint');
      debugPrint('  max_distance: $maxDistance');
      debugPrint('  excluded_cuisines: $excludedCuisines');
      debugPrint('  start_date_str: $startDateStr');
      debugPrint('  end_date_str: $endDateStr');
      debugPrint('  start_time_str: $startTimeStr');
      debugPrint('  end_time_str: $endTimeStr');

      final response = await _serviceClient.rpc(
        'get_restaurants_within_distance_v2',
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

      debugPrint('Raw response from backend: $response');

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
      // Convert hex to binary
      final binary = BigInt.parse(hex, radix: 16);
      // Convert binary to bytes
      final bytes = binary.toRadixString(2).padLeft(64, '0');
      // Parse IEEE 754 double
      final sign = bytes[0] == '1' ? -1 : 1;
      final exponent = int.parse(bytes.substring(1, 12), radix: 2) - 1023;
      final fraction = bytes.substring(12).split('').fold<double>(0, (sum, bit) {
        return sum + (bit == '1' ? 1 / pow(2, 13 + bytes.substring(12).indexOf(bit)) : 0);
      });
      return sign * (1 + fraction) * pow(2, exponent);
    } catch (e) {
      debugPrint('Error converting hex to double: $e');
      return 0.0;
    }
  }
} 