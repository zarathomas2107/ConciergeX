import 'package:geolocator/geolocator.dart';
import 'package:supabase/supabase.dart';

class LocationService {
  final supabase = Supabase.instance.client;

  Future<Map<String, Map<String, double>>> getLondonAreas() async {
    try {
      final response = await supabase
          .from('london_areas')
          .select('name, latitude, longitude')
          .execute();

      final areas = Map<String, Map<String, double>>.fromEntries(
        (response.data as List).map((area) => MapEntry(
          area['name'] as String,
          {
            'lat': area['latitude'] as double,
            'lon': area['longitude'] as double,
          },
        )),
      );

      return areas;
    } catch (e) {
      print('Error fetching London areas: $e');
      // Return default areas as fallback
      return {
        'Covent Garden': {'lat': 51.5117, 'lon': -0.1240},
        'Soho': {'lat': 51.5137, 'lon': -0.1337},
      };
    }
  }
} 