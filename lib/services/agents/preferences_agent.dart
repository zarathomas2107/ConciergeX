import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_openai/dart_openai.dart';
import 'dart:convert';

class PreferencesAgent {
  final SupabaseClient _supabase;
  
  PreferencesAgent(): _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> extractPreferences(String query) async {
    try {
      // Use OpenAI to extract group mentions and dietary preferences
      final completion = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                """Extract group mentions and dietary preferences from the query. Return a JSON object with:
                - groups: Array of group names mentioned with @ symbol
                - dietary_preferences: Array of dietary preferences mentioned
                - price_level: Number 1-4 if price range mentioned
                - meal_time: 'breakfast', 'lunch', or 'dinner' if mentioned
                
                Example: For "@family Italian restaurants for dinner, no pork", return:
                {
                  "groups": ["family"],
                  "dietary_preferences": ["no_pork"],
                  "price_level": null,
                  "meal_time": "dinner"
                }"""
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(query)],
          ),
        ],
      );

      final extractedPrefs = json.decode(
        completion.choices.first.message.content?.firstOrNull?.text ?? '{}'
      ) as Map<String, dynamic>;

      // Get current user's preferences
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return {'error': 'User not authenticated'};
      }

      final userProfile = await _supabase
          .from('profiles')
          .select('dietary_requirements, excluded_cuisines, restaurant_preferences')
          .eq('id', userId)
          .single();

      // Get group preferences if any groups mentioned
      final groupPrefs = await _getGroupPreferences(
        extractedPrefs['groups'] as List<String>? ?? []
      );

      // Combine all preferences
      return {
        'user_preferences': {
          'dietary_requirements': userProfile['dietary_requirements'] ?? {},
          'excluded_cuisines': userProfile['excluded_cuisines'] ?? [],
          'restaurant_preferences': userProfile['restaurant_preferences'] ?? {},
        },
        'group_preferences': groupPrefs,
        'query_preferences': {
          'dietary_preferences': extractedPrefs['dietary_preferences'] ?? [],
          'price_level': extractedPrefs['price_level'],
          'meal_time': extractedPrefs['meal_time'],
        }
      };
    } catch (e) {
      print('Error extracting preferences: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getGroupPreferences(List<String> groupNames) async {
    try {
      if (groupNames.isEmpty) return {};

      // Get group IDs from names
      final groups = await _supabase
          .from('groups')
          .select('id, name')
          .inFilter('name', groupNames);

      final groupIds = groups.map((g) => g['id'].toString()).toList();

      // Get all members' preferences for these groups
      final allPreferences = await Future.wait(
        groupIds.map((groupId) async {
          final group = await _supabase
              .from('groups')
              .select()
              .eq('id', groupId)
              .single();

          final memberIds = List<String>.from(group['member_ids'] ?? []);

          final memberPrefs = await _supabase
              .from('profiles')
              .select('dietary_requirements, excluded_cuisines, restaurant_preferences')
              .inFilter('id', memberIds);

          return memberPrefs;
        })
      );

      // Combine all group members' preferences
      final combined = {
        'dietary_requirements': <String>{},
        'excluded_cuisines': <String>{},
        'restaurant_preferences': <String>{},
      };

      for (final groupPrefs in allPreferences) {
        for (final memberPrefs in groupPrefs) {
          if (memberPrefs['dietary_requirements'] != null) {
            combined['dietary_requirements']
                .addAll(List<String>.from(memberPrefs['dietary_requirements']));
          }
          if (memberPrefs['excluded_cuisines'] != null) {
            combined['excluded_cuisines']
                .addAll(List<String>.from(memberPrefs['excluded_cuisines']));
          }
          if (memberPrefs['restaurant_preferences'] != null) {
            combined['restaurant_preferences']
                .addAll(List<String>.from(memberPrefs['restaurant_preferences']));
          }
        }
      }

      return {
        'dietary_requirements': combined['dietary_requirements']?.toList() ?? [],
        'excluded_cuisines': combined['excluded_cuisines']?.toList() ?? [],
        'restaurant_preferences': combined['restaurant_preferences']?.toList() ?? [],
      };
    } catch (e) {
      print('Error getting group preferences: $e');
      return {};
    }
  }
} 