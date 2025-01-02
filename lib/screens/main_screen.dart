import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../services/restaurant_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _supabase = Supabase.instance.client;
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;
  final _homeScreenKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      debugPrint('Fetching restaurants from Supabase...');
      final data = await _supabase
          .from('restaurants')
          .select()
          .order('Name', ascending: true);
      debugPrint('Received data: $data');

      if (mounted) {
        setState(() {
          _restaurants = (data as List)
              .map((json) => Restaurant.fromSupabase(json))
              .toList();
          debugPrint('Parsed restaurants: ${_restaurants.length}');
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading restaurants: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Error loading restaurants: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handleRestaurantsUpdated(List<Restaurant> restaurants) {
    if (mounted) {
      setState(() => _restaurants = restaurants);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = _supabase.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'ConciergeX',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentIndex == 0
                ? (_error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : HomeScreen(
                            key: _homeScreenKey,
                            restaurants: _restaurants,
                            onRestaurantsUpdated: _handleRestaurantsUpdated,
                          ))
                : const ProfileScreen(),
          ),
          // Search bar above navigation bar
          if (_currentIndex == 0) // Only show search on home screen
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SearchBarWithMentions(
                onSearch: (query) async {
                  if (query.isNotEmpty) {
                    try {
                      await _homeScreenKey.currentState?.filterRestaurants(query);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Search failed: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1 && !isAuthenticated) {
            Navigator.pushNamed(context, '/login');
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: ImageIcon(
              const AssetImage('assets/Icons/home.png'),
              size: 24,
              color: Colors.grey,
            ),
            activeIcon: ImageIcon(
              const AssetImage('assets/Icons/home.png'),
              size: 24,
              color: Colors.white,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(
              const AssetImage('assets/Icons/profile-user.png'),
              size: 24,
              color: Colors.grey,
            ),
            activeIcon: ImageIcon(
              const AssetImage('assets/Icons/profile-user.png'),
              size: 24,
              color: Colors.white,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class SearchBarWithMentions extends StatefulWidget {
  final Function(String) onSearch;

  const SearchBarWithMentions({
    Key? key,
    required this.onSearch,
  }) : super(key: key);

  @override
  _SearchBarWithMentionsState createState() => _SearchBarWithMentionsState();
}

class _SearchBarWithMentionsState extends State<SearchBarWithMentions> {
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final _restaurantService = RestaurantService();
  List<Map<String, dynamic>> _groups = [];
  bool _showGroupSuggestions = false;
  int _mentionStart = -1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final text = _searchController.text;
    final selection = _searchController.selection;
    
    if (selection.baseOffset != selection.extentOffset) return;
    
    // Find the last @ symbol before the cursor
    final beforeCursor = text.substring(0, selection.baseOffset);
    _mentionStart = beforeCursor.lastIndexOf('@');
    
    if (_mentionStart >= 0 && _mentionStart == beforeCursor.length - 1) {
      // Just typed @, show all groups
      _loadGroups();
    } else if (_mentionStart >= 0 && beforeCursor.substring(_mentionStart + 1).contains(' ')) {
      // If there's a space after @, hide suggestions
      setState(() {
        _showGroupSuggestions = false;
      });
    } else if (_mentionStart >= 0) {
      // Filter groups based on what's typed after @
      final query = beforeCursor.substring(_mentionStart + 1).toLowerCase();
      setState(() {
        _groups = _groups.where((group) => 
          group['name'].toString().toLowerCase().contains(query)
        ).toList();
        _showGroupSuggestions = _groups.isNotEmpty;
      });
    } else {
      setState(() {
        _showGroupSuggestions = false;
      });
    }
  }

  Future<void> _loadGroups() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final groups = await _restaurantService.getAvailableGroups(userId);
      if (mounted) {
        setState(() {
          _groups = groups;
          _showGroupSuggestions = groups.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error loading groups: $e');
    }
  }

  void _selectGroup(Map<String, dynamic> group) {
    final text = _searchController.text;
    final beforeMention = text.substring(0, _mentionStart);
    final afterMention = text.substring(_searchController.selection.baseOffset);
    final newText = '$beforeMention@${group['name']}$afterMention';
    
    setState(() {
      _searchController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: _mentionStart + group['name'].toString().length + 1,
        ),
      );
      _showGroupSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          maxLines: null,
          minLines: 1,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search restaurants (e.g., "Italian near Apollo Theatre")...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            isDense: true,
          ),
          onSubmitted: widget.onSearch,
        ),
        if (_showGroupSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return ListTile(
                  title: Text(group['name']),
                  onTap: () => _selectGroup(group),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}