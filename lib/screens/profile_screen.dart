import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/restaurant_service.dart';
import '../models/group.dart';
import '../models/restaurant.dart';
import 'groups_screen.dart';
import 'preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  List<Restaurant> _searchResults = [];
  Map<String, bool> _dietaryRequirements = {};
  Map<String, bool> _restaurantPreferences = {};
  Set<String> _excludedCuisines = {};
  Group? _selectedGroup;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>>? _groupSuggestions;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final userId = _supabase.auth.currentUser?.id;
      debugPrint('Current user ID: $userId');

      if (userId == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final user = _supabase.auth.currentUser!;
      debugPrint('User email: ${user.email}');
      debugPrint('User metadata: ${user.userMetadata}');
      debugPrint('User data: ${user.toJson()}');

      // Try to get existing profile
      final data = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      debugPrint('Raw profile data: $data');
      debugPrint('First name from profile: ${data?['first_name']}');
      debugPrint('Last name from profile: ${data?['last_name']}');

      // If no profile exists, create one
      if (data == null) {
        final newProfile = {
          'id': user.id,
          'email': user.email,
          'first_name': user.userMetadata?['first_name'] ?? '',
          'last_name': user.userMetadata?['last_name'] ?? '',
          'phone': user.phone,
          'email_notifications': false,
          'push_notifications': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final response = await _supabase
            .from('profiles')
            .insert(newProfile)
            .select()
            .single();

        setState(() {
          _profile = response;
          _loading = false;
        });
      } else {
        // Update the profile with any missing fields
        final updatedProfile = {
          ...data,
          'email': data['email'] ?? user.email,
          'first_name': data['first_name'] ?? user.userMetadata?['first_name'] ?? '',
          'last_name': data['last_name'] ?? user.userMetadata?['last_name'] ?? '',
          'phone': data['phone'] ?? user.phone,
          'email_notifications': data['email_notifications'] ?? false,
          'push_notifications': data['push_notifications'] ?? false,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (data['email'] != user.email || 
            data['first_name'] != (user.userMetadata?['first_name'] ?? '') ||
            data['last_name'] != (user.userMetadata?['last_name'] ?? '')) {
          final response = await _supabase
              .from('profiles')
              .update(updatedProfile)
              .eq('id', userId)
              .select()
              .single();
          
          setState(() {
            _profile = response;
            _loading = false;
          });
        } else {
          setState(() {
            _profile = data;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() {
        _error = 'Error loading profile';
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  Future<void> _searchRestaurants(String searchTerm) async {
    final restaurantService = RestaurantService();
    final userId = _supabase.auth.currentUser?.id;
    
    if (userId != null) {
      try {
        final response = await restaurantService.searchWithAgent(searchTerm, userId);
        setState(() {
          _searchResults = response.restaurants;
        });
      } catch (e) {
        debugPrint('Error searching restaurants: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error searching restaurants: $e')),
          );
        }
      }
    }
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search restaurants...',
        suffixIcon: _groupSuggestions != null ? 
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() => _groupSuggestions = null);
            },
          ) : null,
      ),
      onChanged: (value) async {
        // Show group suggestions when @ is typed
        if (value.contains('@')) {
          final lastAtIndex = value.lastIndexOf('@');
          final partial = value.substring(lastAtIndex + 1).toLowerCase();
          
          final restaurantService = RestaurantService();
          final userId = _supabase.auth.currentUser?.id;
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
      },
      onSubmitted: _searchRestaurants,
    );
  }

  Widget _buildGroupSuggestions() {
    if (_groupSuggestions == null || _groupSuggestions!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _groupSuggestions!.map((group) => ListTile(
          title: Text(group['name']),
          subtitle: Text('${group['member_count']} members'),
          leading: Icon(
            group['is_owner'] ? Icons.star : Icons.group,
            color: group['is_owner'] ? Colors.amber : null,
          ),
          onTap: () {
            final cursorPos = _searchController.selection.base.offset;
            final textBefore = _searchController.text.substring(0, cursorPos);
            final lastAtIndex = textBefore.lastIndexOf('@');
            
            final newText = textBefore.substring(0, lastAtIndex) +
                '@${group['name']} ' +
                _searchController.text.substring(cursorPos);
            
            _searchController.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                offset: lastAtIndex + (group['name'] as String).length + 2,
              ),
            );
            
            setState(() => _groupSuggestions = null);
          },
        )).toList(),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    final restaurantService = RestaurantService();
    final userId = _supabase.auth.currentUser?.id;
    
    if (userId != null) {
      try {
        final response = await restaurantService.searchWithAgent(query, userId);
        setState(() {
          _searchResults = response.restaurants;
        });
      } catch (e) {
        debugPrint('Error performing search: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error performing search: $e')),
          );
        }
      }
    }
  }

  void _handleLogout() async {
    // Clear any stored user data or authentication tokens
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Navigate to login screen and remove all previous routes
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Widget _buildProfileHeader() {
    final firstName = _profile?['first_name'] as String? ?? '';
    
    return Container(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.person, size: 60, color: Colors.grey),
            if (firstName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 24),
                _buildProfileHeader(),
                const SizedBox(height: 64),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  title: const Text('Email'),
                  subtitle: Text(_profile?['email'] ?? 'Not set'),
                  leading: Icon(Icons.email, size: 26.4, color: Colors.white),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  leading: const Icon(Icons.settings),
                  title: const Text('Preferences'),
                  subtitle: const Text('Manage your dining preferences and groups'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PreferencesScreen(
                          isUserPreferences: true,
                          initialPreferences: {
                            'dietary_requirements': _dietaryRequirements.keys.where((k) => _dietaryRequirements[k] ?? false).toList(),
                            'restaurant_preferences': _restaurantPreferences.keys.where((k) => _restaurantPreferences[k] ?? false).toList(),
                            'excluded_cuisines': _excludedCuisines.toList(),
                          },
                          onPreferencesSaved: (prefs) {
                            setState(() {
                              _dietaryRequirements = Map.fromIterable(
                                prefs['dietary_requirements'] as List,
                                key: (item) => item as String,
                                value: (item) => true,
                              );
                              _restaurantPreferences = Map.fromIterable(
                                prefs['restaurant_preferences'] as List,
                                key: (item) => item as String,
                                value: (item) => true,
                              );
                              _excludedCuisines = Set.from(prefs['excluded_cuisines'] as List);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  title: const Text('Groups'),
                  subtitle: const Text('Manage your groups and preferences'),
                  leading: Icon(Icons.group, size: 26.4, color: Colors.white),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GroupsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  title: const Text('Logout'),
                  leading: Icon(Icons.logout, size: 26.4, color: Colors.white),
                  onTap: _handleLogout,
                ),
              ],
            ),
      ),
    );
  }
}