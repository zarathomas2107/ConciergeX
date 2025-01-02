import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchService {
  final String _baseUrl;
  final _supabase = Supabase.instance.client;
  
  SearchService({String? baseUrl}) : _baseUrl = baseUrl ?? 'http://localhost:8000';

  Future<Map<String, dynamic>> searchRestaurants(String query) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'query': query,
          'user_id': userId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error from search service: ${response.body}');
      }

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('Error in search service: $e');
      return {'error': e.toString()};
    }
  }
} 