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
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      // Default search parameters
      final defaultParams = {
        'restaurant_name': '',
        'cuisine_type': '',
        'start_date': dateStr,
        'end_date': dateStr,
        'start_time': '19:00',
        'end_time': '21:00',
        'requested_seats': 2,
      };

      final response = await _restaurantService.searchWithParams(defaultParams);
      
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
      final results = await _restaurantService.searchWithParams(params);
      
      setState(() {
        _restaurants = results;
        if (results.isEmpty) {
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
      body: Column(
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search restaurants...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (query) {
                      if (query.isNotEmpty) {
                        _handleSearch(query);
                        _searchController.clear();
                      }
                    },
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _handleSearch(_searchController.text);
                      _searchController.clear();
                    }
                  },
                  color: Colors.green,
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
    _scrollController.dispose();
    super.dispose();
  }
} 