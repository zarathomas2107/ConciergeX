import 'package:supabase_flutter/supabase_flutter.dart';

class CuisineTypes {
  static final _supabase = Supabase.instance.client;
  static List<String> _cuisineTypes = [];

  static Future<List<String>> get all async {
    if (_cuisineTypes.isEmpty) {
      try {
        final response = await _supabase
            .from('restaurants')
            .select('CuisineType')
            .not('CuisineType', 'is', null);

        final cuisines = response as List<dynamic>;
        _cuisineTypes = cuisines
            .map((r) => r['CuisineType'] as String)
            .toSet() // Remove duplicates
            .toList()
            ..sort(); // Sort alphabetically

        print('Loaded ${_cuisineTypes.length} cuisine types from database');
      } catch (e) {
        print('Error loading cuisine types: $e');
        // Fallback to some basic types if query fails
        _cuisineTypes = [
          'Italian',
          'French',
          'Indian',
          'Chinese',
          'Japanese',
          'British',
          'American',
        ];
      }
    }
    return _cuisineTypes;
  }
} 