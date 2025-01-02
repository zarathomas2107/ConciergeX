import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../widgets/restaurant_card.dart';
import '../services/restaurant_service.dart';
import 'dart:math';

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
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _restaurants = widget.restaurants;
    _filteredRestaurants = _restaurants;
  }

  Future<void> filterRestaurants(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredRestaurants = _restaurants;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final restaurantService = RestaurantService();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final results = await restaurantService.searchWithAgent(query, userId);
      
      setState(() {
        _filteredRestaurants = results;
        _isSearching = false;
      });

      // Debug print
      for (var restaurant in results) {
        print('Restaurant: ${restaurant.name}, Distance: ${restaurant.distance}m');
      }
    } catch (e) {
      print('Error filtering restaurants: $e');
      setState(() {
        _filteredRestaurants = [];
        _isSearching = false;
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search restaurants (e.g., "Italian near Soho")',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onSubmitted: (value) => filterRestaurants(value),
              ),
            ),
            // Loading indicator or results
            Expanded(
              child: _isSearching 
                ? const Center(child: CircularProgressIndicator())
                : _filteredRestaurants.isEmpty
                  ? const Center(
                      child: Text('No restaurants found. Try a different search.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _filteredRestaurants.length,
                      itemBuilder: (context, index) {
                        final restaurant = _filteredRestaurants[index];
                        return RestaurantCard(
                          restaurant: restaurant,
                          onTap: () {
                            // Handle restaurant selection
                          },
                        );
                      },
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
    super.dispose();
  }
}