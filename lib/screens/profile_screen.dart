import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'groups_screen.dart';
import 'preferences_screen.dart';

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
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
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
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.person, size: 50),
                    ),
                    const SizedBox(height: 32),
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
                        MaterialPageRoute(builder: (_) => const PreferencesScreen()),
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