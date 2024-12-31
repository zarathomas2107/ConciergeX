import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Visualization'),
      ),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        styleUri: "mapbox://styles/mapbox/streets-v12",
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(-0.1278, 51.5074)), // London coordinates
          zoom: 12.0,
        ),
        onMapCreated: (MapboxMap mapboxMap) {
          _mapController = mapboxMap;
          _addMapMarkers();
        },
      ),
    );
  }

  /// Add a Marker to the Map
  void _addMapMarkers() async {
    await _mapController?.annotations.createPointAnnotationManager()
      .then((manager) {
        manager.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(-0.1278, 51.5074)),
          textField: "Hello London!",
          iconSize: 1.5,
        ));
      });
  }
} 