import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_openai/dart_openai.dart';
import 'dart:convert';

class QueryAgent {
  final SupabaseClient _supabase;
  
  QueryAgent(): _supabase = Supabase.instance.client;

  Future<String> generateQuery(Map<String, dynamic> params) async {
    try {
      final completion = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                """Generate a PostgreSQL query for the restaurants table based on the provided parameters.
                Available columns:
                - RestaurantID
                - Name
                - CuisineType
                - Address
                - Rating
                - PriceLevel (1-4)
                - Latitude
                - Longitude
                - Features (JSONB with boolean flags)
                
                The query should:
                1. Filter by cuisine type if specified
                2. Apply price level filter if specified
                3. Calculate distance if venue coordinates provided
                4. Filter by dietary requirements and excluded cuisines
                5. Order by distance (if venue provided) or rating
                6. Limit to 20 results

                Return only the SQL query string."""
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(
              json.encode(params)
            )],
          ),
        ],
      );

      return completion.choices.first.message.content?.firstOrNull?.text ?? '';
    } catch (e) {
      print('Error generating query: $e');
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> executeSearch({
    required Map<String, dynamic> venue,
    required Map<String, dynamic> preferences,
    String? cuisineType,
  }) async {
    try {
      // Prepare parameters for query generation
      final params = {
        'venue': venue,
        'preferences': preferences,
        'cuisine_type': cuisineType,
      };

      // Generate the SQL query
      final queryString = await generateQuery(params);
      if (queryString.isEmpty) {
        return [];
      }

      // Execute the query using Supabase's raw query functionality
      final response = await _supabase
          .rpc('custom_restaurant_search', params: {
            'query_string': queryString
          });

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error executing search: $e');
      return [];
    }
  }
} 