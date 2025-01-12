import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final MAPBOX_ACCESS_TOKEN = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

void initializeMapbox() {
  MapboxOptions.setAccessToken(MAPBOX_ACCESS_TOKEN);
} 