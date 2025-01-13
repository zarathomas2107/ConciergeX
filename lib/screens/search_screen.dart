class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _restaurantService = RestaurantService(Supabase.instance.client);
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<Restaurant> _restaurants = [];
  List<Map<String, String>> _chatHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialRestaurants();
  }

  Future<void> _loadInitialRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get today's date
      final now = DateTime.now();
      final startDate = now;
      final endDate = now;
      final startTime = const TimeOfDay(hour: 0, minute: 0);
      final endTime = const TimeOfDay(hour: 22, minute: 0);

      final response = await _restaurantService.getRestaurantsNearVenue(
        'VyTA Covent Garden',  // Default venue
        5000.0,  // 5km radius
        [],  // No excluded cuisines
        startDate,
        endDate,
        startTime,
        endTime,
      );
      
      setState(() {
        _restaurants = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading initial restaurants: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _chatHistory.add({
        'message': query,
        'sender': 'user',
        'timestamp': DateTime.now().toIso8601String(),
      });
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final params = _restaurantService.parseSearchQuery(query);
      debugPrint('Full API Response: $params');
      
      // Extract datetime info from params
      final datetime = params['datetime'] as Map<String, dynamic>?;
      
      final startDate = datetime?['start_date'] != null 
          ? DateTime.parse(datetime!['start_date']) 
          : DateTime.now();
      final endDate = datetime?['end_date'] != null 
          ? DateTime.parse(datetime!['end_date']) 
          : DateTime.now();
      
      // Parse time strings to TimeOfDay
      final startTimeStr = datetime?['start_time'] ?? '';
      final endTimeStr = datetime?['end_time'] ?? '';
      
      final startTimeParts = startTimeStr.isNotEmpty ? startTimeStr.split(':') : null;
      final endTimeParts = endTimeStr.isNotEmpty ? endTimeStr.split(':') : null;
      
      final startTime = startTimeParts != null ? TimeOfDay(
        hour: int.parse(startTimeParts[0]), 
        minute: int.parse(startTimeParts[1])
      ) : const TimeOfDay(hour: 0, minute: 0);
      
      final endTime = endTimeParts != null ? TimeOfDay(
        hour: int.parse(endTimeParts[0]), 
        minute: int.parse(endTimeParts[1])
      ) : const TimeOfDay(hour: 22, minute: 0);
      debugPrint('Final TimeOfDay - Start: ${startTime.format(context)}, End: ${endTime.format(context)}');

      // Format times in HH24:MI:SS format
      final startTimeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
      final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

      // Get excluded cuisines
      List<String> excludedCuisines = [];
      if (params['preferences']['excluded_cuisines'] != null) {
        var excluded = params['preferences']['excluded_cuisines'];
        if (excluded is List) {
          excludedCuisines = List<String>.from(excluded.map((e) => e.toString()));
        } else if (excluded is String) {
          excludedCuisines = [excluded];
        }
      }

      // Get required cuisines
      List<String> requiredCuisines = [];
      if (params['preferences']['cuisine_types'] != null) {
        var required = params['preferences']['cuisine_types'];
        if (required is List) {
          requiredCuisines = List<String>.from(required.map((e) => e.toString()));
        } else if (required is String) {
          requiredCuisines = [required];
        }
      }

      final results = await _restaurantService.getRestaurantsNearVenue(
        'VyTA Covent Garden',  // Default venue
        5000.0,  // 5km radius
        excludedCuisines,
        requiredCuisines,
        startDate,
        endDate,
        startTimeStr,
        endTimeStr,
      );
      
      // Filter out restaurants with any excluded cuisines
      final filteredResults = results.where((restaurant) {
        // If there are no excluded cuisines, include the restaurant
        if (excludedCuisines.isEmpty) return true;
        
        // Check if any of the restaurant's cuisines match any excluded cuisine
        return !restaurant.cuisineTypes.any((cuisine) => 
          excludedCuisines.any((excluded) => 
            cuisine.toLowerCase().contains(excluded.toLowerCase())
          )
        );
      }).toList();
      
      setState(() {
        _restaurants = filteredResults;
        if (filteredResults.isEmpty) {
          _chatHistory.add({
            'message': 'No restaurants found matching your criteria.',
            'sender': 'assistant',
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _chatHistory.add({
          'message': 'An error occurred. Please try again.',
          'sender': 'assistant',
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: _chatHistory.length + _restaurants.length,
                itemBuilder: (context, index) {
                  if (index < _chatHistory.length) {
                    final chat = _chatHistory[index];
                    return ChatBubble(
                      message: chat['message']!,
                      isUser: chat['sender'] == 'user',
                    );
                  } else {
                    final restaurantIndex = index - _chatHistory.length;
                    return RestaurantCard(
                      restaurant: _restaurants[restaurantIndex],
                      onTap: () {
                        // Handle restaurant selection
                      },
                      startDate: DateTime.now(),
                      endDate: DateTime.now(),
                      startTime: const TimeOfDay(hour: 0, minute: 0),
                      endTime: const TimeOfDay(hour: 22, minute: 0),
                    );
                  }
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: Colors.grey[100],
                      ),
                      child: TextField(
                        controller: _searchController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Search restaurants...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          hintStyle: TextStyle(color: Colors.grey[600]),
                        ),
                        onSubmitted: (query) {
                          if (query.isNotEmpty) {
                            _handleSearch(query);
                            _searchController.clear();
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: () {
                        if (_searchController.text.isNotEmpty) {
                          _handleSearch(_searchController.text);
                          _searchController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 