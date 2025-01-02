import 'package:dart_openai/dart_openai.dart';
import 'dart:convert';
import 'agents/venue_agent.dart';
import 'agents/preferences_agent.dart';
import 'agents/query_agent.dart';

class SearchOrchestrator {
  final VenueAgent _venueAgent;
  final PreferencesAgent _preferencesAgent;
  final QueryAgent _queryAgent;

  SearchOrchestrator()
      : _venueAgent = VenueAgent(),
        _preferencesAgent = PreferencesAgent(),
        _queryAgent = QueryAgent();

  Future<Map<String, dynamic>> processQuery(String query) async {
    try {
      print('\n=== Starting Search Query Processing ===');
      print('Original query: $query');

      // First, use OpenAI to understand the high-level intent
      final completion = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                """Analyze the search query and extract key components. Return a JSON object with:
                - has_venue: boolean indicating if a specific venue is mentioned
                - has_cuisine: boolean indicating if a specific cuisine is mentioned
                - has_preferences: boolean indicating if any dietary or other preferences are mentioned
                - has_groups: boolean indicating if any group mentions (@) are present
                - cuisine_type: the type of cuisine if mentioned
                
                Example: For "@family Italian restaurants near Apollo Theatre, no pork", return:
                {
                  "has_venue": true,
                  "has_cuisine": true,
                  "has_preferences": true,
                  "has_groups": true,
                  "cuisine_type": "Italian"
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

      final intent = json.decode(
        completion.choices.first.message.content?.firstOrNull?.text ?? '{}'
      ) as Map<String, dynamic>;

      print('Query intent: $intent');

      // Parallel processing of venue and preferences
      final venueResult = intent['has_venue'] == true
          ? _venueAgent.validateVenue(query)
          : Future.value(<String, dynamic>{});

      final preferencesResult = _preferencesAgent.extractPreferences(query);

      final results = await Future.wait([venueResult, preferencesResult]);
      final venue = results[0] as Map<String, dynamic>;
      final preferences = results[1] as Map<String, dynamic>;

      print('Venue details: $venue');
      print('Preferences: $preferences');

      // Execute the search using the query agent
      final restaurants = await _queryAgent.executeSearch(
        venue: venue,
        preferences: preferences,
        cuisineType: intent['cuisine_type'] as String?,
      );

      print('Found ${restaurants.length} matching restaurants');

      return {
        'restaurants': restaurants,
        'venue': venue,
        'preferences': preferences,
        'cuisine_type': intent['cuisine_type'],
      };
    } catch (e) {
      print('Error in search orchestration: $e');
      return {'error': e.toString()};
    }
  }
} 