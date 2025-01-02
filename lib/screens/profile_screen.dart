import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/ai_service.dart';
import '../models/group.dart';
import 'groups_screen.dart';
import 'preferences_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _uploadingImage = false;
  String? _error;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, bool> _dietaryRequirements = {};
  Map<String, bool> _restaurantPreferences = {};
  Set<String> _excludedCuisines = {};
  Group? _selectedGroup;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>>? _groupSuggestions;

  Future<void> _uploadProfilePicture() async {
    try {
      setState(() => _uploadingImage = true);
      debugPrint('Starting image upload process...');

      // Pick image from gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
        requestFullMetadata: false,
      );

      debugPrint('Image picked: ${image?.path}');

      if (image == null) {
        debugPrint('No image selected');
        setState(() => _uploadingImage = false);
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      debugPrint('User ID: $userId');

      // Read file as bytes for iOS compatibility
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last.toLowerCase();
      final fileName = '$userId/profile.$fileExt';
      
      debugPrint('Uploading file: $fileName');
      
      // First try to delete any existing profile picture
      try {
        await _supabase.storage
            .from('profile_pictures')
            .remove(['$userId/profile.jpg', '$userId/profile.jpeg', '$userId/profile.png']);
      } catch (e) {
        debugPrint('No existing profile picture to delete or error: $e');
      }

      // Upload new profile picture
      final response = await _supabase.storage
          .from('profile_pictures')
          .uploadBinary(
            fileName, 
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$fileExt',
            ),
          );
      debugPrint('Upload response: $response');

      // Get public URL for the image
      final imageUrl = _supabase.storage
          .from('profile_pictures')
          .getPublicUrl(fileName);
      debugPrint('Image URL: $imageUrl');

      // Update profile with new avatar URL
      await _supabase
          .from('profiles')
          .update({
            'avatar_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      debugPrint('Profile updated with new avatar URL');

      // Reload profile
      await _loadProfile();
      debugPrint('Profile reloaded');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error uploading image: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: _uploadingImage ? null : _uploadProfilePicture,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _profile?['avatar_url'] != null
                      ? NetworkImage(_profile!['avatar_url'])
                      : null,
                  child: _uploadingImage
                      ? const CircularProgressIndicator()
                      : _profile?['avatar_url'] == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _uploadingImage ? Icons.hourglass_empty : Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_profile?['first_name'] ?? ''} ${_profile?['last_name'] ?? ''}'.trim(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_profile?['email'] != null) ...[
            const SizedBox(height: 4),
            Text(
              _profile!['email'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

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
          'avatar_url': null,
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
    final aiService = AIService();
    final userId = _supabase.auth.currentUser?.id;
    
    if (userId != null) {
      final processedQuery = await aiService.processSearchQuery(searchTerm, userId);
      
      final results = await aiService.searchRestaurants(
        searchTerm: processedQuery['cuisine_type'] ?? searchTerm,
        groupIds: List<String>.from(processedQuery['group_ids'] ?? []),
        userPreferences: {
          'dietary_requirements': _dietaryRequirements,
          'excluded_cuisines': _excludedCuisines,
          'restaurant_preferences': _restaurantPreferences,
        },
      );

      setState(() {
        _searchResults = results;
      });
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
          
          final aiService = AIService();
          final userId = _supabase.auth.currentUser?.id;
          if (userId != null) {
            final groups = await aiService.getUserGroups(userId);
            
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
      onSubmitted: _performSearch,
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
    final aiService = AIService();
    final userId = _supabase.auth.currentUser?.id;
    
    if (userId != null) {
      final processedQuery = await aiService.processSearchQuery(query, userId);
      // Now perform the search with the processed query
      final results = await aiService.searchRestaurants(
        searchTerm: processedQuery['cuisine_type'] ?? query,
        groupIds: List<String>.from(processedQuery['group_ids'] ?? []),
        userPreferences: {
          'dietary_requirements': _dietaryRequirements,
          'excluded_cuisines': _excludedCuisines,
          'restaurant_preferences': _restaurantPreferences,
        },
      );

      setState(() {
        _searchResults = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: ImageIcon(
              const AssetImage('assets/Icons/logout.png'),
              size: 24,
              color: Colors.white,
            ),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No profile found'),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildProfileHeader(),
                    const Divider(),
                    ListTile(
                      title: const Text('Name'),
                      subtitle: Text('${_profile?['first_name'] ?? 'Not set'} ${_profile?['last_name'] ?? ''}'),
                      leading: ImageIcon(
                        const AssetImage('assets/Icons/id-card.png'),
                        size: 26.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Email'),
                      subtitle: Text(_profile?['email'] ?? 'Not set'),
                      leading: ImageIcon(
                        const AssetImage('assets/Icons/mail.png'),
                        size: 26.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Preferences'),
                      subtitle: const Text('Manage your dietary and location preferences'),
                      leading: ImageIcon(
                        const AssetImage('assets/Icons/like.png'),
                        size: 26.4,
                        color: Colors.white,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PreferencesScreen(
                            isUserPreferences: true,
                            initialPreferences: {
                              'dietary_requirements': _profile?['dietary_requirements'] ?? [],
                              'restaurant_preferences': _profile?['restaurant_preferences'] ?? [],
                              'excluded_cuisines': _profile?['excluded_cuisines'] ?? [],
                            },
                            onPreferencesSaved: (preferences) async {
                              try {
                                // Update the profile with new preferences
                                final userId = _supabase.auth.currentUser?.id;
                                if (userId != null) {
                                  final response = await _supabase
                                      .from('profiles')
                                      .update({
                                        'dietary_requirements': preferences['dietary_requirements'],
                                        'restaurant_preferences': preferences['restaurant_preferences'],
                                        'excluded_cuisines': preferences['excluded_cuisines'],
                                        'updated_at': DateTime.now().toIso8601String(),
                                      })
                                      .eq('id', userId)
                                      .select()
                                      .single();
                                  
                                  setState(() {
                                    _profile = response;
                                  });
                                }
                                Navigator.pop(context);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error saving preferences: $e')),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Groups'),
                      subtitle: const Text('Manage your groups and preferences'),
                      leading: Image.asset(
                        'assets/Icons/dinner.png',
                        width: 26.4,
                        height: 26.4,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroupsScreen()),
                      ),
                    ),
                  ],
                ),
    );
  }
}