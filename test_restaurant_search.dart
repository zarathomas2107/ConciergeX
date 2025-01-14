import 'package:supabase/supabase.dart';
import 'dart:convert';

void main() async {
  // Initialize Supabase with service role key
  final supabase = SupabaseClient(
    'https://ryvqoavkltzagedrvymy.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ5dnFvYXZrbHR6YWdlZHJ2eW15Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNTk4ODM4OSwiZXhwIjoyMDUxNTY0Mzg5fQ.KBTUy-96ji2QNWrJYttmg7Ov4Qqrv7PW3aZ3yE1QFdM',
  );

  final encoder = JsonEncoder.withIndent('  ');

  try {
    print('Running test...\n');

    // First, check if we have any data in restaurants_availability
    print('Checking restaurants_availability table directly...');
    final availabilityResponse = await supabase
        .from('restaurants_availability')
        .select()
        .eq('id', 'ChIJa4kFNsoFdkgRLuOyhQkoBRg') // VyTA's ID
        .gte('date', '2025-01-12')
        .lte('date', '2025-01-12');
    
    print('Direct query results:');
    print(encoder.convert(availabilityResponse));
    print('');

    // Test parameters with smaller radius
    final params = {
      'ref_point': 'POINT(-0.1240436 51.5116571)',
      'max_distance': 1000.0,
      'excluded_cuisines': ['French', 'Indian', 'Chinese'],
      'start_date_str': '2025-01-12',
      'end_date_str': '2025-01-30',
      'start_time_str': '00:00:00',
      'end_time_str': '23:59:59',
    };

    print('Querying restaurants with params: ${jsonEncode(params)}\n');

    // Call the RPC function with debug
    print('Calling RPC function...');
    final response = await supabase.rpc(
      'get_restaurants_within_distance_v2',
      params: params,
    );

    print('\nRaw Response Type: ${response.runtimeType}');
    print('Raw Response Data:');
    print(encoder.convert(response));
    print('');

    // Extract VyTA Covent Garden details with more debug info
    final restaurants = response as List;
    print('Number of restaurants returned: ${restaurants.length}');
    
    final vytaRestaurant = restaurants.firstWhere(
      (r) => r['name'] == 'VyTA Covent Garden',
      orElse: () => null,
    );

    if (vytaRestaurant != null) {
      print('\nVyTA Covent Garden found!');
      print('VyTA Details:');
      print(encoder.convert(vytaRestaurant));
      print('');

      print('Available Slots Data Type: ${vytaRestaurant['available_slots']?.runtimeType}');
      print('Available Slots Raw Data:');
      print(encoder.convert(vytaRestaurant['available_slots']));
      
      if (vytaRestaurant['available_slots'] != null) {
        final slots = vytaRestaurant['available_slots'];
        print('\nTrying to parse slots...');
        try {
          if (slots is String) {
            print('Slots is a String, attempting to parse as JSON...');
            final parsedSlots = jsonDecode(slots);
            print('Parsed JSON type: ${parsedSlots.runtimeType}');
            print('Parsed JSON:');
            print(encoder.convert(parsedSlots));
          } else if (slots is List) {
            print('Slots is already a List with ${slots.length} items');
            print('First slot sample (if available):');
            if (slots.isNotEmpty) {
              print(encoder.convert(slots.first));
            }
          } else {
            print('Unexpected slots type: ${slots.runtimeType}');
          }
        } catch (e) {
          print('Error parsing slots: $e');
        }
      }
    } else {
      print('VyTA Covent Garden not found in results');
    }

  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Close the Supabase client
    supabase.dispose();
  }
} 