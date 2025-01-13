import 'package:supabase_flutter/supabase_flutter.dart';

class CuisineTypes {
  static final _supabase = Supabase.instance.client;
  static List<String> _cuisineTypes = [];

  static Future<List<String>> get all async {
    if (_cuisineTypes.isEmpty) {
      try {
        final response = await _supabase
            .from('restaurants')
            .select('cuisine_type');

        final cuisines = response as List<dynamic>;
        final allCuisineTypes = <String>{};
        
        // Extract all unique cuisine types from the arrays
        for (var restaurant in cuisines) {
          if (restaurant['cuisine_type'] != null) {
            final types = (restaurant['cuisine_type'] as List<dynamic>)
                .map((e) => e.toString());
            allCuisineTypes.addAll(types);
          }
        }

        _cuisineTypes = allCuisineTypes.toList()..sort();
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