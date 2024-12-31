MapWidget(
  key: ValueKey('map_$restaurantId'),
  resourceOptions: ResourceOptions(accessToken: mapboxToken),
  cameraOptions: CameraOptions(
    center: Point(coordinates: Position(restaurant.longitude, restaurant.latitude)).toJson(),
    zoom: 15.0,
  ),
  styleUri: MapboxStyles.MAPBOX_STREETS,
  textureView: true,
  attribution: AttributionSettings(
    enabled: false,
  ),
) 