import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import 'ai_service.dart';

class RestaurantService {
  final _supabase = Supabase.instance.client;
  final _aiService = AIService();

  Future<List<Restaurant>> searchWithLLM(String query) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final result = await _aiService.processSearchQuery(query, userId);
      
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Search failed');
      }

      final restaurants = result['restaurants'] as List;
      return restaurants.map((data) => Restaurant.fromJson(data)).toList();
    } catch (e) {
      print('Error in searchWithLLM: $e');
      return [];
    }
  }
} 