import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  
  late final CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(_venueLat, _venueLon),
    zoom: 14.0,
  );

  final Map<String, Map<String, double>> locationCoords = {
    'Covent Garden': {'lat': 51.5117, 'lon': -0.1240},
    'Soho': {'lat': 51.5137, 'lon': -0.1337},
    'Lyceum': {'lat': 51.5115, 'lon': -0.1200},
  };

  @override
  void initState() {
    super.initState();
    _restaurants = widget.restaurants;
    _filteredRestaurants = _restaurants;
    _searchController.addListener(_onSearchChanged);
    
    // Create markers for initial restaurants
    for (final restaurant in _restaurants) {
      if (restaurant.latitude != 0 && restaurant.longitude != 0) {
        _createCustomMarker(restaurant.name).then((customMarker) {
          if (mounted) {
            setState(() {
              _markers.add(
                Marker(
                  markerId: MarkerId(restaurant.id),
                  position: LatLng(restaurant.latitude, restaurant.longitude),
                  icon: customMarker,
                  anchor: const Offset(0.5, 0.5),
                  infoWindow: InfoWindow(
                    title: restaurant.name,
                    snippet: restaurant.distance != null 
                        ? '${restaurant.cuisineTypes.join(' • ')} • ${(restaurant.distance! / 1000).toStringAsFixed(1)}km'
                        : restaurant.cuisineTypes.join(' • '),
                  ),
                ),
              );
            });
          }
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _showMap = true;
      });
      _updateMap();
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Only update map if markers are empty
    if (_markers.isEmpty) {
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
    const size = Size(60, 60);  // Reduced from 400x400

    final circlePaint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      const Offset(30, 30),  // Adjusted position
      25,  // Reduced from 150
      circlePaint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _updateMap() async {
    if (_mapController == null) return;

    setState(() {
      _markers.clear();
    });
      
    // Use filtered restaurants if search has been performed, otherwise show all restaurants
    final restaurantsToShow = _hasSearched ? _filteredRestaurants : _restaurants;
    
    for (final restaurant in restaurantsToShow) {
      if (restaurant.latitude != 0 && restaurant.longitude != 0) {
        final customMarker = await _createCustomMarker(restaurant.name);
        if (mounted) {
          setState(() {
            _markers.add(
              Marker(
                markerId: MarkerId(restaurant.id),
                position: LatLng(restaurant.latitude, restaurant.longitude),
                icon: customMarker,
                anchor: const Offset(0.5, 0.5),
                infoWindow: InfoWindow(
                  title: restaurant.name,
                  snippet: restaurant.distance != null 
                      ? '${restaurant.cuisineTypes.join(' • ')} • ${(restaurant.distance! / 1000).toStringAsFixed(1)}km'
                      : restaurant.cuisineTypes.join(' • '),
                ),
                onTap: () {
                  final index = restaurantsToShow.indexOf(restaurant);
                  if (index != -1) {
                    _scrollController.animateTo(
                      index * (MediaQuery.of(context).size.width * 0.95 + 16),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            );
          });
        }
      }
    }
  }

  Future<void> _filterRestaurants(SearchResponse searchResponse) async {
    try {
      if (searchResponse.restaurants.isNotEmpty) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
          _filteredRestaurants = searchResponse.restaurants;
          
          // Get datetime from root level of response
          final datetime = searchResponse.datetime;
          debugPrint('Got datetime from response: $datetime');
          
          if (datetime != null) {
            // Parse the datetime info from backend
            final startTimeStr = datetime['start_time'] as String?;
            final endTimeStr = datetime['end_time'] as String?;
            final startDateStr = datetime['start_date'] as String?;
            final endDateStr = datetime['end_date'] as String?;
            
            if (startTimeStr != null && endTimeStr != null) {
              // Parse time strings in format HH:MM:SS
              final startTimeParts = startTimeStr.split(':');
              final endTimeParts = endTimeStr.split(':');
              
              _currentStartTime = TimeOfDay(
                hour: int.parse(startTimeParts[0]),
                minute: int.parse(startTimeParts[1]),
              );
              
              _currentEndTime = TimeOfDay(
                hour: int.parse(endTimeParts[0]),
                minute: int.parse(endTimeParts[1]),
              );
            }
            
            if (startDateStr != null && endDateStr != null) {
              _currentStartDate = DateTime.parse(startDateStr);
              _currentEndDate = DateTime.parse(endDateStr);
            }
            
            debugPrint('Updated datetime parameters:');
            debugPrint('  start_date: $_currentStartDate');
            debugPrint('  end_date: $_currentEndDate');
            debugPrint('  start_time: ${_currentStartTime?.format(context)}');
            debugPrint('  end_time: ${_currentEndTime?.format(context)}');
          }
        });
        
        // Update map markers to show only filtered restaurants
        _updateMap();
      } else {
        setState(() {
          _filteredRestaurants = [];
          _isSearching = false;
          _hasSearched = true;
        });
        
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
      
      // Clear all restaurant markers on error
      _updateMap();
    }
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
        _showMap = true;  // Ensure map stays visible on reset
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showMap = true;  // Keep map visible while searching
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        debugPrint('Searching with query: $query');
        final searchResponse = await _restaurantService.searchWithAgent(query, userId);
        debugPrint('Search response location: ${searchResponse.location}');
        debugPrint('Found ${searchResponse.restaurants.length} restaurants');
        
        setState(() => _showMap = true);  // Ensure map stays visible after search
        
        // Update venue location if provided
        if (searchResponse.location != null) {
          debugPrint('Location data: ${searchResponse.location}');
          final locationStr = searchResponse.location!['address'] as String?;
          if (locationStr != null && locationStr.isNotEmpty) {
            // Parse the location string which is in format 'POINT(lon lat)'
            final coordsStr = locationStr.replaceAll('POINT(', '').replaceAll(')', '');
            final coords = coordsStr.split(' ');
            if (coords.length == 2) {
              try {
                _venueLon = double.parse(coords[0]);
                _venueLat = double.parse(coords[1]);
                debugPrint('Updating venue coordinates: lat=$_venueLat, lon=$_venueLon');
                _updateMap();
              } catch (e) {
                debugPrint('Error parsing coordinates: $e');
              }
            }
          }
        }
        
        await _filterRestaurants(searchResponse);
      }
    } catch (e) {
      debugPrint('Error searching: $e');
      setState(() {
        _filteredRestaurants = [];
        _isSearching = false;
        _hasSearched = true;
        _showMap = true;  // Keep map visible even on error
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
          GoogleMap(
            key: const ValueKey<String>('google_map'),
            onMapCreated: _onMapCreated,
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            padding: const EdgeInsets.only(bottom: 200),
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
                          final restaurant = _filteredRestaurants[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.95,
                              child: RestaurantCard(
                                restaurant: restaurant,
                                startDate: _hasSearched ? _currentStartDate : null,
                                endDate: _hasSearched ? _currentEndDate : null,
                                startTime: _hasSearched ? _currentStartTime : null,
                                endTime: _hasSearched ? _currentEndTime : null,
                                onAvailabilityCheck: _hasSearched ? (slots) {
                                  debugPrint('Showing availability dialog for ${restaurant.name} with ${slots.length} slots');
                                  _showAvailabilityDialog(restaurant, slots);
                                } : null,
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
    if (_mapController != null) {
      _mapController!.dispose();
      _mapController = null;
    }
    _scrollController.dispose();
    _hideGroupSuggestions();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }
}