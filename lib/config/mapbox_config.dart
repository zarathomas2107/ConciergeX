import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class MapboxConfig {
  static String get accessToken => dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  
  static Future<void> initialize() async {
    await dotenv.load();
    if (accessToken.isEmpty) {
      throw Exception('Mapbox access token not found in .env file');
    }
    debugPrint('Mapbox access token loaded successfully');
  }
} 