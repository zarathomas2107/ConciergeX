import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../services/restaurant_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'groups_screen.dart';

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
          .order('name', ascending: true);
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

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = _supabase.auth.currentUser != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(),
      bottomNavigationBar: Container(
        height: 87,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          iconSize: 24,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        children: [
                          HomeScreen(
                            key: _homeScreenKey,
                            restaurants: _restaurants,
                            onRestaurantsUpdated: _handleRestaurantsUpdated,
                          ),
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 8,
                            right: 16,
                            child: IconButton(
                              icon: const Icon(Icons.group),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const GroupsScreen()),
                                );
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.grey[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                        ],
                      ),
              const ProfileScreen(),
            ],
          ),
        ),
      ],
    );
  }
}