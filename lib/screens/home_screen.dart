import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' show ImageByteFormat, PictureRecorder, TextDirection;
import '../models/restaurant.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/availability_dialog.dart';
import '../services/restaurant_service.dart';
import 'dart:math';

final GOOGLE_API_KEY = dotenv.env['GOOGLE_API_KEY'] ?? '';

class HomeScreen extends StatefulWidget {
  final List<Restaurant> restaurants;
  final Function(List<Restaurant>) onRestaurantsUpdated;

  const HomeScreen({
    Key? key,
    required this.restaurants,
    required this.onRestaurantsUpdated,
  }) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Restaurant> _restaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final _restaurantService = RestaurantService();
  final _supabase = Supabase.instance.client;
  GoogleMapController? _mapController;
  bool _showMap = false;
  double _venueLat = 51.5073219;  // Default to London
  double _venueLon = -0.1276474;
  String? _currentLocationName;
  Set<Marker> _markers = {};
  DateTime? _currentStartDate;
  DateTime? _currentEndDate;
  TimeOfDay? _currentStartTime;
  TimeOfDay? _currentEndTime;
  final ScrollController _scrollController = ScrollController();
  bool _hasSearched = false;
  List<Map<String, dynamic>> _groupSuggestions = [];
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _loadingLocation = false;
  
  late final CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(_venueLat, _venueLon),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _restaurants = widget.restaurants;
    _filteredRestaurants = _restaurants;
    _searchController.addListener(_onSearchChanged);
    
    // Delay getting location to avoid map creation issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocationAndRestaurants();
    });
  }

  Future<void> _getCurrentLocationAndRestaurants() async {
    setState(() => _loadingLocation = true);

    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      debugPrint('Got current position: lat=${position.latitude}, lon=${position.longitude}');

      if (!mounted) return;

      setState(() {
        _venueLat = position.latitude;
        _venueLon = position.longitude;
        _currentLocationName = 'Current Location';
        _showMap = true;
      });

      // Update map camera
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_venueLat, _venueLon),
            zoom: 15.0,
          ),
        ),
      );

      // Format the current location as a point string
      final pointStr = 'POINT(${position.longitude} ${position.latitude})';
      debugPrint('Searching with point: $pointStr');
      
      // Get today's date in YYYY-MM-DD format
      final today = DateTime.now();
      final dateStr = today.toIso8601String().split('T')[0];
      
      debugPrint('Fetching restaurants within 5km of current location');
      final response = await _supabase
          .rpc('get_restaurants_within_distance_v4', params: {
            'ref_point': pointStr,
            'max_distance': 5000.0,
            'excluded_cuisines': [],
            'required_cuisines': ['Vegetarian'],
            'start_date_str': dateStr,
            'end_date_str': dateStr,
            'start_time_str': '09:00:00',
            'end_time_str': '22:00:00'
          });
          
      debugPrint('Got response from Supabase: $response');

      if (!mounted) return;

      // Debug log for raw data
      if (response is List && response.isNotEmpty) {
        final firstRestaurant = response.first as Map;
        debugPrint('First restaurant raw data: $firstRestaurant');
        debugPrint('First restaurant name: ${firstRestaurant['name']}');
        debugPrint('First restaurant cuisine types: ${firstRestaurant['cuisine_type']}');
        debugPrint('First restaurant vegetarian scale: ${firstRestaurant['vegetarian_scale']}');
      }

      final restaurants = (response as List)
          .map((r) => Restaurant.fromJson(r as Map<String, dynamic>))
          .toList();
          
      debugPrint('Parsed ${restaurants.length} restaurants');
      if (restaurants.isNotEmpty) {
        debugPrint('First restaurant: ${restaurants.first.name}');
        debugPrint('First restaurant vegetarian scale: ${restaurants.first.vegetarianScale}');
      }

      setState(() {
        debugPrint('Setting state with ${restaurants.length} restaurants');
        _filteredRestaurants = restaurants;
        _isSearching = false;
        _hasSearched = true;
        debugPrint('State updated, filtered restaurants: ${_filteredRestaurants.length}');
      });

      debugPrint('Updating map with ${restaurants.length} restaurants');
      // Update map with all restaurants
      _updateMap();

    } catch (e, stackTrace) {
      debugPrint('Error getting location or restaurants: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading nearby restaurants: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (_mapController != null) {
      debugPrint('Map controller already exists, disposing old one');
      _mapController!.dispose();
    }
    _mapController = controller;
    debugPrint('New map controller created');
    
    // Only update map if we have markers to show
    if (_markers.isNotEmpty) {
      debugPrint('Updating map with existing markers');
      _updateMap();
    }
  }

  Future<BitmapDescriptor> _createCustomMarker(String name) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(200, 80);  // Reduced from 1200x400

    final circlePaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      const Offset(30, 30),  // Adjusted position
      20,  // Reduced from 120
      circlePaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 24,  // Reduced from 160
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(60, 20));  // Adjusted position

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createVenueMarker() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(80, 80);  // Increased from 60x60

    final circlePaint = Paint()
      ..color = Colors.green.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      const Offset(40, 40),  // Adjusted for new size
      35,  // Increased from 25
      circlePaint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _updateMap() async {
    if (!mounted) return;
    debugPrint('Starting _updateMap with ${_filteredRestaurants.length} restaurants');
    
    final newMarkers = <Marker>{};
    
    for (final restaurant in _filteredRestaurants) {
      try {
        final marker = Marker(
          markerId: MarkerId(restaurant.id),
          position: LatLng(restaurant.latitude, restaurant.longitude),
          infoWindow: InfoWindow(
            title: restaurant.name,
            snippet: restaurant.address,
          ),
        );
        newMarkers.add(marker);
      } catch (e) {
        debugPrint('Error creating marker for ${restaurant.name}: $e');
      }
    }
    
    setState(() {
      _markers = newMarkers;
    });
  }

  Future<void> _filterRestaurants(SearchResponse searchResponse) async {
    try {
      if (searchResponse.restaurants.isNotEmpty) {
        // Get datetime from root level of response first
        final datetime = searchResponse.datetime;
        debugPrint('Got datetime from response: $datetime');
        
        // Set the date range before filtering
        if (datetime != null) {
          final startDateStr = datetime['start_date'] as String?;
          final endDateStr = datetime['end_date'] as String?;
          
          if (startDateStr != null && endDateStr != null) {
            try {
              _currentStartDate = DateTime.parse(startDateStr);
              _currentEndDate = DateTime.parse(endDateStr);
              debugPrint('Set date range from response: $_currentStartDate to $_currentEndDate');
            } catch (e) {
              debugPrint('Error parsing date strings: $e');
              _currentStartDate = DateTime.now();
              _currentEndDate = DateTime.now();
            }
          }
          
          final startTimeStr = datetime['start_time'] as String?;
          final endTimeStr = datetime['end_time'] as String?;
          
          if (startTimeStr != null && endTimeStr != null && startTimeStr.contains(':') && endTimeStr.contains(':')) {
            try {
              final startTimeParts = startTimeStr.split(':');
              final endTimeParts = endTimeStr.split(':');
              
              if (startTimeParts.length >= 2 && endTimeParts.length >= 2) {
                _currentStartTime = TimeOfDay(
                  hour: int.parse(startTimeParts[0]),
                  minute: int.parse(startTimeParts[1]),
                );
                
                _currentEndTime = TimeOfDay(
                  hour: int.parse(endTimeParts[0]),
                  minute: int.parse(endTimeParts[1]),
                );
                
                debugPrint('Set time range from response: ${_currentStartTime?.format(context)} to ${_currentEndTime?.format(context)}');
              }
            } catch (e) {
              debugPrint('Error parsing time strings: $e');
              _currentStartTime = const TimeOfDay(hour: 9, minute: 0);
              _currentEndTime = const TimeOfDay(hour: 22, minute: 0);
            }
          }
        }

        // Filter restaurants to only show those with available slots
        final restaurantsWithSlots = searchResponse.restaurants.where((restaurant) {
          final slots = restaurant.getAvailableSlotsInRange(
            _currentStartDate ?? DateTime.now(),
            _currentEndDate ?? DateTime.now(),
            _currentStartTime ?? const TimeOfDay(hour: 9, minute: 0),
            _currentEndTime ?? const TimeOfDay(hour: 22, minute: 0),
          );
          debugPrint('Checking slots for ${restaurant.name}: ${slots?.length ?? 0} slots found');
          debugPrint('Using date range: ${_currentStartDate} to ${_currentEndDate}');
          debugPrint('Using time range: ${_currentStartTime?.format(context)} - ${_currentEndTime?.format(context)}');
          return slots != null && slots.isNotEmpty;
        }).toList();

        setState(() {
          _isSearching = false;
          _hasSearched = true;
          _filteredRestaurants = restaurantsWithSlots;
        });

        debugPrint('Found ${restaurantsWithSlots.length} restaurants with available slots');
        
        if (restaurantsWithSlots.isEmpty) {
          _showNoRestaurantsMessage();
        }
        
        // Update map markers to show only filtered restaurants
        _updateMap();
      } else {
        setState(() {
          _filteredRestaurants = [];
          _isSearching = false;
          _hasSearched = true;
        });
        
        _showNoRestaurantsMessage();
        
        // Clear all restaurant markers when no results
        _updateMap();
      }
    } catch (e) {
      debugPrint('Error filtering restaurants: $e');
      setState(() {
        _filteredRestaurants = [];
        _isSearching = false;
        _hasSearched = true;
      });
      
      _showNoRestaurantsMessage();
      
      // Clear all restaurant markers on error
      _updateMap();
    }
  }

  void _showNoRestaurantsMessage() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Restaurant Search is not currently available in your local area. Try searches in Soho, Shoreditch, Hackney & London Bridge.',
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
  }

  void _showAvailabilityDialog(Restaurant restaurant, List<AvailabilitySlot> slots) {
    debugPrint('_showAvailabilityDialog called for ${restaurant.name}');
    debugPrint('Number of slots to show: ${slots.length}');
    
    if (!mounted) {
      debugPrint('Widget not mounted, cannot show dialog');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        debugPrint('Building AvailabilityDialog');
        return AvailabilityDialog(
          restaurant: restaurant,
          availableSlots: slots,
        );
      },
    ).then((_) => debugPrint('Dialog closed'));
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredRestaurants = _restaurants;
        _isSearching = false;
        _hasSearched = false;
        _currentStartDate = null;
        _currentEndDate = null;
        _currentStartTime = null;
        _currentEndTime = null;
        _currentLocationName = null;
        _showMap = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showMap = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        debugPrint('Searching with query: $query');
        final searchResponse = await _restaurantService.searchWithAgent(query, userId);
        debugPrint('Search response location: ${searchResponse.location}');
        debugPrint('Found ${searchResponse.restaurants.length} restaurants');
        
        // Store query and response in Supabase
        try {
          await _supabase.from('user_queries').insert({
            'user_id': userId,
            'query': query,
            'llm_response': {
              'location': searchResponse.location,
              'datetime': searchResponse.datetime,
              'num_restaurants': searchResponse.restaurants.length,
              'venue_lat': searchResponse.venueLat,
              'venue_lon': searchResponse.venueLon,
            },
          });
        } catch (e) {
          debugPrint('Error storing query in Supabase: $e');
          // Continue with search even if storing fails
        }
        
        setState(() => _showMap = true);
        
        // Update venue location if provided
        if (searchResponse.venueLat != null && searchResponse.venueLon != null) {
          debugPrint('Updating venue coordinates: lat=${searchResponse.venueLat}, lon=${searchResponse.venueLon}');
          setState(() {
            _venueLat = searchResponse.venueLat!;
            _venueLon = searchResponse.venueLon!;
            _currentLocationName = searchResponse.location?['name'] as String?;
          });
          
          // Animate camera to new venue location
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(_venueLat, _venueLon),
                zoom: 15.0,
              ),
            ),
          );
          
          _updateMap();
        }
        
        await _filterRestaurants(searchResponse);
      }
    } catch (e) {
      debugPrint('Error searching: $e');
      setState(() {
        _filteredRestaurants = [];
        _isSearching = false;
        _hasSearched = true;
        _currentLocationName = null;
        _showMap = true;
      });
    }
  }

  void _onSearchChanged() {
    final text = _searchController.text;
    final selection = _searchController.selection;
    
    if (selection.baseOffset != -1) {
      final textBeforeCursor = text.substring(0, selection.baseOffset);
      final lastAtSymbol = textBeforeCursor.lastIndexOf('@');
      
      if (lastAtSymbol != -1) {
        final query = textBeforeCursor.substring(lastAtSymbol + 1).toLowerCase();
        _showGroupSuggestions(query);
      } else {
        _hideGroupSuggestions();
      }
    }
  }

  void _showGroupSuggestions(String query) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final groups = await _restaurantService.getAvailableGroups(userId);
      if (!mounted) return;

      setState(() {
        _groupSuggestions = groups.where((group) {
          final groupName = group['name'].toString().toLowerCase();
          return groupName.contains(query);
        }).toList();
      });

      _overlayEntry?.remove();
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } catch (e) {
      debugPrint('Error fetching group suggestions: $e');
    }
  }

  void _hideGroupSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width * 0.95,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, 60),  // Adjust this value to position the suggestions below the search bar
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: 400,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _groupSuggestions.length,
                itemBuilder: (context, index) {
                  final group = _groupSuggestions[index];
                  final memberCount = (group['members'] as List?)?.length ?? 0;
                  return ListTile(
                    title: Text(group['name']),
                    subtitle: Text('$memberCount members'),
                    onTap: () {
                      final text = _searchController.text;
                      final selection = _searchController.selection;
                      final textBeforeCursor = text.substring(0, selection.baseOffset);
                      final lastAtSymbol = textBeforeCursor.lastIndexOf('@');
                      
                      final groupName = group['name'].toString();
                      final newText = text.replaceRange(
                        lastAtSymbol + 1, 
                        selection.baseOffset,
                        groupName
                      );
                      
                      _searchController.value = TextEditingValue(
                        text: newText,
                        selection: TextSelection.collapsed(
                          offset: lastAtSymbol + 1 + groupName.length,
                        ),
                      );
                      
                      _hideGroupSuggestions();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          if (_showMap) 
            GoogleMap(
              key: const ValueKey<String>('home_map'),
              onMapCreated: _onMapCreated,
              initialCameraPosition: _initialCameraPosition,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
              padding: const EdgeInsets.only(bottom: 200),
            ),
          if (_loadingLocation)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Finding restaurants near you...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 150,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        _filteredRestaurants.length,
                        (index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 16 : 8,
                              right: index == _filteredRestaurants.length - 1 ? 16 : 8,
                            ),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.95,
                              child: RestaurantCard(
                                restaurant: _filteredRestaurants[index],
                                onAvailabilityCheck: (slots) {
                                  _showAvailabilityDialog(_filteredRestaurants[index], slots);
                                },
                                startDate: _currentStartDate,
                                endDate: _currentEndDate,
                                startTime: _currentStartTime,
                                endTime: _currentEndTime,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _searchController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Search restaurants...',
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _search,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    _scrollController.dispose();
    _hideGroupSuggestions();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }
}