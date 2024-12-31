import 'package:dart_openai/dart_openai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

class AIService {
  final supabase = Supabase.instance.client;
  
  AIService() {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in .env file');
    }
    
    OpenAI.apiKey = apiKey;
  }

  Future<List<Map<String, dynamic>>> getSimilarRestaurants(String restaurantId) async {
    try {
      final response = await supabase.rpc(
        'get_similar_restaurants',
        params: {
          'query_restaurant_id': restaurantId,
          'match_threshold': 0.3,
          'match_count': 5
        },
      );
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error getting similar restaurants: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyVenues(double lat, double lon, {String? venueName}) async {
    try {
      // Try theatres first
      var response = await supabase.rpc(
        'get_nearby_theatres',
        params: {
          'p_lat': lat,
          'p_lon': lon,
          'p_radius': 1000.0,
          'p_name': venueName ?? ''
        },
      );
      
      var results = List<Map<String, dynamic>>.from(response as List);
      
      // If no theatres found, try cinemas
      if (results.isEmpty) {
        response = await supabase.rpc(
          'get_nearby_cinemas',
          params: {
            'p_lat': lat,
            'p_lon': lon,
            'p_radius': 1000.0,
            'p_name': venueName ?? ''
          },
        );
        
        results = List<Map<String, dynamic>>.from(response as List);
      }

      if (results.isEmpty) {
        print('No matching venues found');
      } else {
        // Map the results to a common format
        results = results.map((venue) {
          final isTheatre = venue['venue_type'] == 'theatre';
          return {
            'id': isTheatre ? venue['place_id'] : venue['id'],  // Use place_id for theatres
            'name': venue['name'],
            'address': venue['address'],
            'website': venue['website'],
            'distance': venue['distance'],
            'latitude': venue['latitude'],
            'longitude': venue['longitude'],
            'venue_type': venue['venue_type'] ?? 'venue'
          };
        }).toList();

        results.sort((a, b) => 
          (a['distance'] ?? double.infinity)
          .compareTo(b['distance'] ?? double.infinity)
        );

        if (results.isNotEmpty) {
          print('Found venue: ${results.first['name']} (${results.first['distance']} meters)');
        }
      }
      
      return results;
    } catch (e) {
      print('Error getting nearby venues: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getVenuesByName(String name) async {
    try {
      // Search theatres
      var response = await supabase
          .from('theatres')
          .select('''
            name,
            place_id,
            address,
            phone,
            website,
            rating,
            user_ratings_total,
            latitude,
            longitude,
            types,
            price_level,
            opening_hours,
            google_maps_url,
            location
          ''')
          .ilike('name', '%$name%')
          .limit(5);
      
      var results = List<Map<String, dynamic>>.from(response);
      
      // If no theatres found, search cinemas
      if (results.isEmpty) {
        response = await supabase
            .from('cinemas')
            .select('''
              id,
              name,
              address,
              postcode,
              chain,
              website,
              location
            ''')
            .ilike('name', '%$name%')
            .limit(5);
        
        results = List<Map<String, dynamic>>.from(response);
      }

      return results.map((venue) {
        final location = venue['location'] as Map<String, dynamic>?;
        final coordinates = location?['coordinates'] as List?;
        final isTheatre = venue.containsKey('place_id');
        
        return {
          'id': venue['place_id'] ?? venue['id'],
          'name': venue['name'],
          'address': venue['address'],
          'website': venue['website'],
          'latitude': coordinates?[1] ?? venue['latitude'],
          'longitude': coordinates?[0] ?? venue['longitude'],
          'venue_type': isTheatre ? 'theatre' : 'cinema',
          if (isTheatre) ...{
            'phone': venue['phone'],
            'rating': venue['rating'],
            'price_level': venue['price_level'],
            'opening_hours': venue['opening_hours'],
            'google_maps_url': venue['google_maps_url'],
            'types': venue['types'],
          } else ...{
            'postcode': venue['postcode'],
            'chain': venue['chain'],
          }
        };
      }).toList();
    } catch (e) {
      print('Error searching venues: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> processSearchQuery(String query) async {
    try {
      print('Making OpenAI request...');
      final completion = await OpenAI.instance.chat.create(
        model: dotenv.env['OPENAI_MODEL_ID'] ?? "ft:gpt-3.5-turbo-0125:personal::AjMYeMJb",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                """Extract structured information from the query into JSON format.
                Required fields:
                - cuisine_type: the type of cuisine requested
                - location: specific area or "Covent Garden" if not specified
                
                Optional fields:
                - venue_name: if searching near a specific venue
                - similar_to: if looking for similar restaurants
                - start_time: if time is mentioned
                - end_time: if time range is mentioned
                - features: array of matching features from the list below
                
                Available features:
                - Dog_Friendly: allows dogs
                - Business_Meals: suitable for business meetings
                - Birthdays: good for birthday celebrations
                - Date Nights: romantic or date spots
                - Pre_Theatre: suitable for pre-theatre dining
                - Cheap_Eat: affordable dining
                - Fine_Dining: upscale dining experience
                - kids: child-friendly
                - solo: comfortable for solo diners
                - Bar: has a good bar/drinks
                - Casual_Dinner: good for casual dining
                - Brunch: serves brunch
                - Vegetarian: good vegetarian options
                - Vegan: good vegan options
                - Breakfast: serves breakfast
                - Lunch: serves lunch
                - Dinner: serves dinner
                
                Example responses:
                {
                  "cuisine_type": "Italian",
                  "location": "Covent Garden",
                  "venue_name": "Royal Opera House",
                  "features": ["Pre_Theatre", "Fine_Dining"]
                }
                
                {
                  "cuisine_type": "Any",
                  "location": "Soho",
                  "features": ["Date Nights", "Bar"]
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

      final responseContent = completion.choices.first.message.content?.firstOrNull?.text ?? 'No response from AI';
      final jsonResponse = json.decode(responseContent);
      final location = jsonResponse['location'] as String;
      
      try {
        // Get venue coordinates if available
        double? venueLat, venueLon;
        
        if (jsonResponse['venue_name'] != null) {
          // Get default coordinates for the location
          final defaultCoords = await getAreaCoordinates(location) ?? 
                            {'lat': 51.5117, 'lon': -0.1240}; // Covent Garden default
          
          // Try venue first
          final venues = await getNearbyVenues(
            defaultCoords['lat']!, 
            defaultCoords['lon']!,
            venueName: jsonResponse['venue_name'],
          );
          
          if (venues.isNotEmpty) {
            venueLat = venues.first['latitude'] as double;
            venueLon = venues.first['longitude'] as double;
            print('Using venue coordinates: ${venues.first['name']}');
          }
        }
        
        // If no venue found, try looking up the area
        if (venueLat == null || venueLon == null) {
          final areaCoords = await getAreaCoordinates(location);
          if (areaCoords != null) {
            venueLat = areaCoords['lat'];
            venueLon = areaCoords['lon'];
            print('Using coordinates for area: $location');
          }
        }

        // If we have coordinates, search for restaurants
        if (venueLat != null && venueLon != null) {
          final results = await supabase
              .rpc('nearby_restaurants', params: {
                'ref_lat': venueLat,
                'ref_lon': venueLon,
                'radius_meters': 1000.0,
              });

          // Process results and calculate distances
          final restaurants = (results as List).map((json) {
            final restaurantLat = json['Latitude'] as double;
            final restaurantLon = json['Longitude'] as double;
            
            final distance = calculateDistance(
              venueLat!, 
              venueLon!, 
              restaurantLat, 
              restaurantLon
            );
            
            return {
              'RestaurantID': json['RestaurantID'],
              'Name': json['Name'],
              'CuisineType': json['CuisineType'],
              'Address': json['Address'],
              'Rating': json['Rating'],
              'PriceLevel': json['PriceLevel'],
              'BusinessStatus': json['BusinessStatus'],
              'Latitude': restaurantLat,
              'Longitude': restaurantLon,
              'website': json['website'],
              'City': json['City'],
              'Country': json['Country'],
              'location': json['location'],
              'distance': distance
            };
          }).toList();

          // Sort by distance
          restaurants.sort((a, b) => 
            (a['distance'] as double).compareTo(b['distance'] as double)
          );

          // Update the response with the restaurants
          final response = {
            'cuisine_type': jsonResponse['cuisine_type'],
            'location': location,
            'venue_name': jsonResponse['venue_name'],
            'features': jsonResponse['features'],
            'restaurants': restaurants
          };

          print('Found ${restaurants.length} restaurants near $location');
          return {'response': json.encode(response)};
        }

        // If we get here, return the original response without restaurants
        return {'response': responseContent};
        
      } catch (e) {
        print('Error processing restaurants: $e');
        // Use the jsonResponse from the outer scope
        return {
          'response': json.encode({
            'cuisine_type': jsonResponse['cuisine_type'],
            'location': jsonResponse['location'],
            'venue_name': jsonResponse['venue_name'],
            'features': jsonResponse['features'],
            'restaurants': []
          })
        };
      }
    } catch (e) {
      print('Error in processSearchQuery: $e');
      return {
        'error': e.toString(),
        'response': '{"cuisine_type": "Any", "location": "Covent Garden", "restaurants": []}'
      };
    }
  }

  Future<List<Map<String, dynamic>>> getRestaurantsByFeatures(String query) async {
    try {
      final completion = await OpenAI.instance.chat.create(
        model: dotenv.env['OPENAI_MODEL_ID'] ?? "ft:gpt-3.5-turbo-0125:personal::AjMYeMJb",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                """Match the user's query to these restaurant features and return a JSON object with boolean values:
                Features:
                - Dog_Friendly: allows dogs
                - Business_Meals: suitable for business meetings
                - Birthdays: good for birthday celebrations
                - Date Nights: romantic or date spots
                - Pre_Theatre: suitable for pre-theatre dining
                - Cheap_Eat: affordable dining
                - Fine_Dining: upscale dining experience
                - kids: child-friendly
                - solo: comfortable for solo diners
                - Bar: has a good bar/drinks
                - Casual_Dinner: good for casual dining
                - Brunch: serves brunch
                - Vegetarian: good vegetarian options
                - Vegan: good vegan options
                - Breakfast: serves breakfast
                - Lunch: serves lunch
                - Dinner: serves dinner"""
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(query)],
          ),
        ],
      );

      final responseContent = completion.choices.first.message.content?.firstOrNull?.text ?? '{}';
      final features = json.decode(responseContent) as Map<String, dynamic>;

      final conditions = features.entries
          .where((e) => e.value == true)
          .map((e) => e.key.trim())
          .toList();

      if (conditions.isEmpty) return [];

      // Use a simpler query structure
      final response = await supabase
          .from('restaurants')
          .select('*, restaurants_features(*)')
          .eq('restaurants_features.${conditions[0]}', true)
          .limit(10);

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('Error matching restaurant features: $e');
      return [];
    }
  }

  Future<Map<String, double>?> getAreaCoordinates(String areaName) async {
    try {
      final response = await supabase
          .from('london_areas')
          .select('latitude, longitude')
          .ilike('name', '%$areaName%')
          .single();

      if (response != null) {
        return {
          'lat': response['latitude'] as double,
          'lon': response['longitude'] as double,
        };
      }
      return null;
    } catch (e) {
      print('Error getting area coordinates for $areaName: $e');
      // Return default Covent Garden coordinates as fallback
      return {
        'lat': 51.5117,
        'lon': -0.1240
      };
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3; // Earth's radius in meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi/2) * sin(deltaPhi/2) +
            cos(phi1) * cos(phi2) *
            sin(deltaLambda/2) * sin(deltaLambda/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c; // Distance in meters
  }
} 