import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
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
      body: _currentIndex == 0
          ? (_error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : HomeScreen(
                      restaurants: _restaurants,
                      onRestaurantsUpdated: _handleRestaurantsUpdated,
                    ))
          : const ProfileScreen(),
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