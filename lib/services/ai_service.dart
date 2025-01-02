import 'package:dart_openai/dart_openai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;

class AIService {
  final _supabase = Supabase.instance.client;
  final _baseUrl = 'http://localhost:8000'; // Local Python service
  
  Future<Map<String, dynamic>> processSearchQuery(String query, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'user_id': userId
        })
      );

      if (response.statusCode != 200) {
        throw Exception('Search failed: ${response.body}');
      }

      final result = json.decode(response.body);
      
      // If we have a successful query, execute it via Supabase
      if (result['success'] == true && result['query'] != null) {
        final queryResponse = await _supabase.rpc(
          'execute_search_query',
          params: {
            'query_text': result['query'],
            'query_params': result['parameters']
          }
        );

        return {
          'success': true,
          'restaurants': queryResponse,
          'summary': result['summary']
        };
      }

      return result;
    } catch (e) {
      print('Error in processSearchQuery: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  Future<List<Map<String, dynamic>>> searchRestaurants({
    required String searchTerm,
    List<String>? groupIds,
    Map<String, dynamic>? userPreferences,
  }) async {
    try {
      final response = await _supabase.rpc(
        'search_restaurants',
        params: {
          'search_term': searchTerm,
          'group_ids': groupIds ?? [],
          'user_preferences': userPreferences ?? {}
        }
      );
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error in searchRestaurants: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    try {
      final response = await _supabase
        .from('group_members')
        .select('''
          group:groups (
            id,
            name,
            created_at,
            owner_id,
            member_count
          )
        ''')
        .eq('user_id', userId);

      return (response as List).map((item) {
        final group = item['group'] as Map<String, dynamic>;
        return {
          ...group,
          'is_owner': group['owner_id'] == userId,
        };
      }).toList();
    } catch (e) {
      print('Error getting user groups: $e');
      return [];
    }
  }
} 