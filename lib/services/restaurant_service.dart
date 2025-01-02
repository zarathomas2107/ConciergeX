import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchResponse {
  final List<Restaurant> restaurants;
  final List<Map<String, dynamic>> availableGroups;
  final bool showingGroups;
  final Map<String, dynamic>? preferences;

  SearchResponse({
    required this.restaurants,
    required this.availableGroups,
    required this.showingGroups,
    this.preferences,
  });
}

class RestaurantService {
  final _supabase = Supabase.instance.client;
  final String _baseUrl = 'http://localhost:8000'; // Local Python server

  Future<SearchResponse> searchWithAgent(String query, String userId) async {
    try {
      // Add Apollo Theatre coordinates if not specified in query
      if (!query.toLowerCase().contains('near') && !query.toLowerCase().contains('close to')) {
        query = '$query near Apollo Theatre';
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'user_id': userId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Search failed: ${response.body}');
      }

      final data = json.decode(response.body);
      
      // If available_groups is present in the response, return it
      if (data.containsKey('available_groups')) {
        return SearchResponse(
          restaurants: [],
          availableGroups: (data['available_groups'] as List).cast<Map<String, dynamic>>(),
          showingGroups: true,
          preferences: data['preferences'] as Map<String, dynamic>?,
        );
      }
      
      // Otherwise return restaurants
      final results = data['restaurants'] as List;
      return SearchResponse(
        restaurants: results.map((data) => Restaurant.fromJson(data)).toList(),
        availableGroups: [],
        showingGroups: false,
        preferences: data['preferences'] as Map<String, dynamic>?,
      );
      
    } catch (e) {
      print('Error in searchWithAgent: $e');
      rethrow; // Rethrow to handle in UI
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableGroups(String userId) async {
    try {
      final response = await _supabase
          .from('groups')
          .select()
          .or('created_by.eq.${userId},member_ids.cs.{${userId}}');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting available groups: $e');
      return [];
    }
  }
} 