import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_openai/dart_openai.dart';
import 'dart:convert';

class VenueAgent {
  final SupabaseClient _supabase;
  
  VenueAgent(): _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> validateVenue(String query) async {
    try {
      // Use OpenAI to extract venue information from the query
      final completion = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                """Extract venue information from the query. Return a JSON object with:
                - venue_name: The exact name of the venue
                - venue_type: Either 'theatre' or 'cinema'
                - confidence: A number between 0 and 1 indicating confidence in the extraction
                
                Example: For "restaurants near Odeon Leicester Square", return:
                {
                  "venue_name": "Odeon Leicester Square",
                  "venue_type": "cinema",
                  "confidence": 0.9
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

      final result = json.decode(
        completion.choices.first.message.content?.firstOrNull?.text ?? '{}'
      ) as Map<String, dynamic>;

      if (result['confidence'] < 0.5) {
        return {'error': 'Could not confidently identify venue'};
      }

      // Query Supabase for venue details
      final venueType = result['venue_type']?.toString().toLowerCase();
      final venueName = result['venue_name']?.toString();

      if (venueType == 'cinema') {
        final response = await _supabase
            .from('cinemas')
            .select()
            .ilike('name', '%$venueName%')
            .limit(1)
            .single();

        if (response != null) {
          final location = response['location'] as Map<String, dynamic>?;
          final coordinates = location?['coordinates'] as List?;
          
          return {
            'id': response['id'],
            'name': response['name'],
            'type': 'cinema',
            'latitude': coordinates?[1],
            'longitude': coordinates?[0],
            'address': response['address'],
          };
        }
      } else {
        final response = await _supabase
            .from('theatres')
            .select()
            .ilike('name', '%$venueName%')
            .limit(1)
            .single();

        if (response != null) {
          final location = response['location'] as Map<String, dynamic>?;
          final coordinates = location?['coordinates'] as List?;
          
          return {
            'id': response['place_id'],
            'name': response['name'],
            'type': 'theatre',
            'latitude': coordinates?[1],
            'longitude': coordinates?[0],
            'address': response['address'],
          };
        }
      }

      return {'error': 'Venue not found in database'};
    } catch (e) {
      print('Error in venue validation: $e');
      return {'error': e.toString()};
    }
  }
} 