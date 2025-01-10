import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../config/mapbox_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/restaurant_service.dart';
import '../widgets/restaurant_card.dart';
import '../models/restaurant.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final MAPBOX_ACCESS_TOKEN = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

// Public interface for HomeScreen state
abstract class HomeScreenState extends State<HomeScreen> {
  void updateMap();
  Future<void> filterRestaurants(String query);
}

class HomeScreen extends StatefulWidget {
  final List<Restaurant> restaurants;
  final Function(List<Restaurant>)? onRestaurantsUpdated;

  const HomeScreen({
    super.key, 
    this.restaurants = const [], 
    this.onRestaurantsUpdated,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _PointAnnotationClickListener extends OnPointAnnotationClickListener {
  final Function(PointAnnotation) onClick;

  _PointAnnotationClickListener(this.onClick);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onClick(annotation);
  }
}

class _HomeScreenState extends HomeScreenState {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _restaurants = [];
  bool _isLoading = false;
  String _searchQuery = '';
  geo.Position? _currentPosition;
  bool _showMap = false;
  late final double _devicePixelRatio;
  String _venueName = '';
  double _venueLat = 0.0;
  double _venueLon = 0.0;
  Map<String, Restaurant> _markerIdToRestaurant = {};
  Map<String, dynamic>? _groupPreferences;
  List<Map<String, dynamic>>? _groupSuggestions;
  final TextEditingController _searchController = TextEditingController();

  @override
  Future<void> filterRestaurants(String query) async {
    setState(() {
      _searchQuery = query;
      _restaurants = widget.restaurants.where((restaurant) {
        final name = restaurant.name.toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower);
      }).toList();
    });
    updateMap();
  }

  @override
  void initState() {
    super.initState();
    _devicePixelRatio = PlatformDispatcher.instance.views.first.devicePixelRatio;
    _restaurants = List.from(widget.restaurants);
    _initializeLocation();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.restaurants != oldWidget.restaurants) {
      setState(() {
        _restaurants = List.from(widget.restaurants);
      });
    }
  }

  @override
  void dispose() {
    _circleAnnotationManager?.deleteAll();
    _pointAnnotationManager?.deleteAll();
    _circleAnnotationManager = null;
    _pointAnnotationManager = null;
    _mapboxMap = null;
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    debugPrint('Map creation started');
    _mapboxMap = mapboxMap;
    
    try {
      debugPrint('Using Mapbox token: ${MAPBOX_ACCESS_TOKEN.substring(0, 10)}...');
      debugPrint('Setting initial camera position...');
      await mapboxMap.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(-0.1276474, 51.5073219)
          ),
          zoom: 12.0,
        )
      );
      
      debugPrint('Initial camera position set');
      setState(() {
        _showMap = true;
      });
    } catch (e) {
      debugPrint('Error initializing map: $e');
    }
  }

  void _onStyleLoaded(StyleLoadedEventData event) async {
    debugPrint("Style loaded event received");
    if (!mounted || _mapboxMap == null) {
      debugPrint("Widget not mounted or map not initialized, skipping map update");
      return;
    }

    // Update map if we have venue information
    if (_venueName.isNotEmpty && _venueLat != 0.0 && _venueLon != 0.0) {
      updateMap();
    }
  }

  @override
  void updateMap() async {
    if (_mapboxMap == null) {
      debugPrint('Map not initialized');
      return;
    }

    try {
      debugPrint('Starting map update with venue: $_venueName at $_venueLon, $_venueLat');
      
      // Clear existing annotations and mapping
      _markerIdToRestaurant.clear();
      
      // Create new annotation managers
      _circleAnnotationManager = await _mapboxMap!.annotations.createCircleAnnotationManager();
      _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
      
      // Set up click listener
      _pointAnnotationManager?.addOnPointAnnotationClickListener(
        _PointAnnotationClickListener((annotation) {
          debugPrint('Marker clicked: ${annotation.id}');
          final restaurant = _markerIdToRestaurant[annotation.id];
          if (restaurant != null) {
            debugPrint('Found restaurant: ${restaurant.name}');
            final index = _restaurants.indexWhere((r) => r.id == restaurant.id);
            if (index != -1) {
              debugPrint('Scrolling to index: $index');
              _scrollController.animateTo(
                index * 130.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          }
        })
      );

      // Add venue marker if we have venue information
      if (_venueName.isNotEmpty && _venueLat != 0.0 && _venueLon != 0.0) {
        debugPrint('Adding venue marker...');
        
        // Add circle marker for the venue location
        await _circleAnnotationManager!.create(
          CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(_venueLon, _venueLat)
            ),
            circleColor: Colors.red.value,
            circleRadius: 15.0,
            circleStrokeWidth: 3.0,
            circleStrokeColor: Colors.white.value,
          ),
        );
        debugPrint('Added circle marker');

        // Add text annotation for the venue name
        await _pointAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(_venueLon, _venueLat)
            ),
            textField: _venueName,
            textSize: 14.0,
            textOffset: [0, 3.0],
            textColor: Colors.black.value,
            textHaloColor: Colors.white.value,
            textHaloWidth: 3.0,
          ),
        );
        debugPrint('Added text annotation');
        
        // Add top 10 restaurants
        final top10Restaurants = _restaurants.take(10).toList();
        for (var restaurant in top10Restaurants) {
          if (restaurant.latitude != null && restaurant.longitude != null) {
            // Add circle marker for restaurant
            final circle = await _circleAnnotationManager!.create(
              CircleAnnotationOptions(
                geometry: Point(
                  coordinates: Position(restaurant.longitude, restaurant.latitude)
                ),
                circleColor: Colors.blue.value,
                circleRadius: 10.0,
                circleStrokeWidth: 2.0,
                circleStrokeColor: Colors.white.value,
              ),
            );

            // Add text annotation for restaurant name and store the mapping
            final point = await _pointAnnotationManager!.create(
              PointAnnotationOptions(
                geometry: Point(
                  coordinates: Position(restaurant.longitude, restaurant.latitude)
                ),
                textField: '${restaurant.name} (${restaurant.rating}★)',
                textSize: 12.0,
                textOffset: [0, 2.0],
                textColor: Colors.black.value,
                textHaloColor: Colors.white.value,
                textHaloWidth: 2.0,
              ),
            );
            
            // Store the mapping between marker and restaurant
            _markerIdToRestaurant[point.id] = restaurant;
          }
        }
        
        debugPrint('Added marker for venue: $_venueName at $_venueLon, $_venueLat');
        
        // Center map on the venue location with animation
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(_venueLon, _venueLat)
            ),
            zoom: 14.0,
          ),
          MapAnimationOptions(duration: 1000),
        );
        debugPrint('Centered map on venue: $_venueName');
      } else {
        debugPrint('No venue information available');
      }
    } catch (e) {
      debugPrint('Error updating map: $e');
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;  // Math.PI / 180
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 + 
            c(lat1 * p) * c(lat2 * p) * 
            (1 - c((lon2 - lon1) * p))/2;
    return 12742 * math.asin(math.sqrt(a)) * 1000; // 2 * R * asin(sqrt(a)) where R = 6371 km, result in meters
  }

  void _onScroll() {
    // Remove map update on scroll
    // updateMap();
  }

  Future<void> _handleSearch(String query) async {
    setState(() {
      _isLoading = true;
      _searchQuery = query;
      _groupPreferences = null;  // Reset group preferences on new search
      _groupPreferences = null;  // Reset group preferences on new search
    });

    try {
      final restaurantService = RestaurantService();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (userId != null) {
        final searchResponse = await restaurantService.searchWithAgent(query, userId);
        debugPrint('Got search response: ${searchResponse.preferences}');
        
        if (mounted) {
          // Sort restaurants by distance
          final restaurants = searchResponse.restaurants;
          restaurants.sort((a, b) {
            final distanceA = a.distance ?? double.infinity;
            final distanceB = b.distance ?? double.infinity;
            return distanceA.compareTo(distanceB);

          // Get group preferences if available
          final groupPrefs = searchResponse.groupPreferences;
          if (groupPrefs != null) {
            debugPrint('Found group preferences: $groupPrefs');
          }
          });

          // Parse venue information
          String venueName = '';
          double venueLat = 0.0;
          double venueLon = 0.0;

          // Get location data from the response
          if (searchResponse.location != null) {
            debugPrint('Location found in response: ${searchResponse.location}');
            venueName = searchResponse.location!['name']?.toString() ?? '';
            
            // Get coordinates from points_of_interest table
            if (venueName.isNotEmpty) {
              try {
                final venueData = await Supabase.instance.client
                    .from('points_of_interest')
                    .select('latitude, longitude')
                    .eq('name', venueName)
                    .single();
                
                if (venueData != null) {
                  venueLat = venueData['latitude'] as double;
                  venueLon = venueData['longitude'] as double;
                  debugPrint('Found venue coordinates: $venueLon, $venueLat');
                }
              } catch (e) {
                debugPrint('Error getting venue coordinates: $e');
              }
            }
          } else {
            debugPrint('No location found in response');
          }

          setState(() {
            _restaurants = restaurants;
            _showMap = true;
            _isLoading = false;
            _venueName = venueName;
            _venueLat = venueLat;
            _groupPreferences = searchResponse.groupPreferences;
            _venueLon = venueLon;
          });
          
          debugPrint('Before updateMap: venue=$_venueName, lat=$_venueLat, lon=$_venueLon');
          updateMap();
        }
      }
    } catch (e) {
      debugPrint('Error searching restaurants: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching restaurants: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double _hexToDouble(String hex) {
    // Convert hex string to int
    int value = int.parse(hex, radix: 16);
    // Convert int to bytes
    List<int> bytes = [];
    for (int i = 0; i < 8; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    // Create a ByteData view
    ByteData data = ByteData(8);
    for (int i = 0; i < 8; i++) {
      data.setUint8(i, bytes[i]);
    }
    // Read as double
    return data.getFloat64(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_groupPreferences != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Card(
              child: ExpansionTile(
                title: Text('Group: ${_groupPreferences!['name']}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_groupPreferences!['dietary_requirements']?.isNotEmpty == true)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dietary Requirements:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: (_groupPreferences!['dietary_requirements'] as List)
                                    .map((req) => Chip(label: Text(req.toString())))
                                    .toList(),
                              ),
                            ],
                          ),
                        if (_groupPreferences!['excluded_cuisines']?.isNotEmpty == true)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                'Excluded Cuisines:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: (_groupPreferences!['excluded_cuisines'] as List)
                                    .map((cuisine) => Chip(label: Text(cuisine.toString())))
                                    .toList(),
                              ),
                            ],
                          ),
                        if (_groupPreferences!['restaurant_preferences']?.isNotEmpty == true)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                'Restaurant Preferences:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: (_groupPreferences!['restaurant_preferences'] as List)
                                    .map((pref) => Chip(label: Text(pref.toString())))
                                    .toList(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_showMap)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.2,
                child: MapWidget(
                  key: const ValueKey("mapWidget"),
                  onMapCreated: _onMapCreated,
                  onStyleLoadedListener: _onStyleLoaded,
                  styleUri: "mapbox://styles/mapbox/streets-v12",
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(-0.1276474, 51.5073219)
                    ),
                    zoom: 12.0,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              if (_restaurants.isEmpty && !_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No restaurants found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: _restaurants.length,
                  itemBuilder: (context, index) {
                    final restaurant = _restaurants[index] is Restaurant 
                      ? _restaurants[index] as Restaurant
                      : Restaurant.fromJson(_restaurants[index] as Map<String, dynamic>);
                    return RestaurantCard(
                      restaurant: restaurant,
                      onTap: () {
                        // Handle restaurant selection
                      },
                    );
                  },
                ),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onSubmitted: _handleSearch,
                onChanged: _handleSearchChange,
                decoration: InputDecoration(
                  hintText: 'Search restaurants near a venue... (Type @ to mention a group)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _groupSuggestions != null ? 
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _groupSuggestions = null;
                        });
                      },
                    ) : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              if (_groupSuggestions != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: _groupSuggestions!.map((group) => ListTile(
                      title: Text(group['name']),
                      onTap: () {
                        final currentText = _searchController.text;
                        final lastAtIndex = currentText.lastIndexOf('@');
                        final newText = currentText.substring(0, lastAtIndex) + '@${group['name']} ';
                        _searchController.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(offset: newText.length),
                        );
                        setState(() {
                          _groupSuggestions = null;
                        });
                      },
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSearchChange(String value) async {
    if (value.contains('@')) {
      final lastAtIndex = value.lastIndexOf('@');
      final partial = value.substring(lastAtIndex + 1).toLowerCase();
      
      final restaurantService = RestaurantService();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final groups = await restaurantService.getAvailableGroups(userId);
        
        setState(() {
          _groupSuggestions = groups
              .where((g) => g['name'].toLowerCase().contains(partial))
              .toList();
        });
      }
    } else {
      setState(() => _groupSuggestions = null);
    }
  }
}