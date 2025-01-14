import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import 'member_preferences_screen.dart';
import 'preferences_screen.dart';
import '../utils/string_extensions.dart';
import 'profile_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _supabase = Supabase.instance.client;
  final _groupNameController = TextEditingController();
  List<Group> _groups = [];
  List<User> _selectedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _groups = [];
          _loading = false;
        });
        return;
      }

      final groupsResponse = await _supabase
          .from('groups')
          .select()
          .or('created_by.eq.${userId},member_ids.cs.{${userId}}');

      if (groupsResponse == null) {
        setState(() {
          _groups = [];
          _loading = false;
        });
        return;
      }

      final groups = (groupsResponse as List).map((groupData) {
        try {
          return Group(
            id: groupData['id'],
            name: groupData['name'],
            memberIds: List<String>.from(groupData['member_ids'] ?? []),
            createdBy: groupData['created_by'],
            createdAt: DateTime.parse(groupData['created_at']),
          );
        } catch (e) {
          debugPrint('Error parsing group: $e');
          return null;
        }
      }).whereType<Group>().toList();

      if (mounted) {
        setState(() {
          _groups = groups;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading groups: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _groups = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _createGroup() async {
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AddGroupDialog(),
      ),
    );

    if (result == null || !mounted) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get the group name and selected users from the dialog result
      final name = result['name'] as String;
      final selectedUsers = result['selectedUsers'] as List<User>;

      // Create member_ids array with creator and selected users
      final memberIds = [userId, ...selectedUsers.map((u) => u.id)];

      await _supabase.from('groups').insert({
        'name': name,
        'created_by': userId,
        'member_ids': memberIds,
      });

      if (mounted) {
        // Schedule reload for next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadGroups();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    }
  }

  Future<void> _showUserSelectionDialog() async {
    final result = await showDialog<User>(
      context: context,
      builder: (context) => AddMemberDialog(),
    );
    
    if (result != null) {
      setState(() {
        _selectedUsers.add(result);
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadMemberDetails(List<String> memberIds) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('''
            id,
            first_name,
            last_name,
            email,
            dietary_requirements,
            restaurant_preferences,
            location_preferences
          ''')
          .inFilter('id', memberIds);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading member details: $e');
      return [];
    }
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
        title: const Text('Groups'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGroups,
              child: ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: 80.0, // Add padding at bottom for FAB
                ),
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ExpansionTile(
                      title: Text(group.name),
                      subtitle: Text('${group.memberIds.length} members'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteGroup(group),
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _loadMemberDetails(group.memberIds),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No members'),
                                );
                              }
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _addMember(group),
                                          icon: const Icon(Icons.person_add),
                                          label: const Text('Add Member'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...snapshot.data!.map((member) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      title: Text(
                                        '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim(),
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      subtitle: member['email'] != null 
                                        ? Text(
                                            member['email'],
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () {
                                              // Helper function to safely convert to List<String>
                                              List<String> toStringList(dynamic value) {
                                                if (value == null) return [];
                                                if (value is List) return List<String>.from(value);
                                                if (value is String) return [value];
                                                return [];
                                              }

                                              final groupMember = GroupMember(
                                                id: member['id'],
                                                name: member['first_name'] + ' ' + (member['last_name'] ?? ''),
                                                dietaryRequirements: toStringList(member['dietary_requirements']),
                                                restaurantPreferences: toStringList(member['restaurant_preferences']),
                                                locationPreferences: toStringList(member['location_preferences']),
                                                excludedCuisines: toStringList(member['excluded_cuisines']),
                                              );
                                              _editMemberPreferences(group, groupMember);
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          const SizedBox(width: 8),
                                          // Only show delete button if:
                                          // 1. Current user is the creator and not removing themselves
                                          // 2. Current user is removing themselves
                                          if ((group.createdBy == _supabase.auth.currentUser?.id && 
                                               member['id'] != _supabase.auth.currentUser?.id) ||
                                              (group.createdBy != _supabase.auth.currentUser?.id && 
                                               member['id'] == _supabase.auth.currentUser?.id))
                                            IconButton(
                                              icon: const Icon(Icons.person_remove),
                                              onPressed: () => _removeMember(group, member['id']),
                                              color: Colors.red,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                        ],
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 4.0,
                                      ),
                                    ),
                                  )).toList(),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        backgroundColor: Colors.black,
        child: const Icon(
          Icons.add,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _addMember(Group group) async {
    if (!mounted) return;

    try {
      final result = await showDialog<User>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext context) => WillPopScope(
          onWillPop: () async => false,
          child: AddMemberDialog(),
        ),
      );
      
      if (result == null || !mounted) return;

      setState(() => _loading = true);

      // Add retry logic for Supabase operation
      int retryCount = 0;
      const maxRetries = 3;
      while (retryCount < maxRetries) {
        try {
          // Update the group's member_ids array
          final updatedMemberIds = [...group.memberIds, result.id];
          
          await _supabase
              .from('groups')
              .update({
                'member_ids': updatedMemberIds,
              })
              .eq('id', group.id);
          
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          if (retryCount == maxRetries) {
            throw e; // Throw on final retry
          }
          // Wait before retrying
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (!mounted) return;
      
      // Add retry logic for loading groups
      retryCount = 0;
      while (retryCount < maxRetries) {
        try {
          await _loadGroups();
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          if (retryCount == maxRetries) {
            throw e; // Throw on final retry
          }
          // Wait before retrying
          await Future.delayed(Duration(seconds: 1));
        }
      }
      
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member added successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error in _addMember: $e');
      if (mounted) {
        setState(() => _loading = false);
        
        // Show a more user-friendly error message
        final errorMessage = e.toString().contains('Connection reset') 
            ? 'Connection error. Please check your internet connection and try again.'
            : 'Error adding member. Please try again.';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _addMember(group),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editMemberPreferences(Group group, GroupMember member) async {
    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MemberPreferencesScreen(
          member: member,
          groupId: group.id,
          isCreator: group.createdBy == _supabase.auth.currentUser?.id,
          onRemoveMember: () => _removeMember(group, member.id),
        ),
      ),
    );
    
    // If true was returned, member was removed
    if (result == true) {
      return;
    }
    
    // Reload group details after returning from preferences screen
    if (mounted) {
      setState(() {
        _loading = true;
      });
      await _loadGroups();
    }
  }

  Future<void> _deleteGroup(Group group) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "${group.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await _supabase
          .from('groups')
          .delete()
          .eq('id', group.id);

      if (mounted) {
        setState(() {
          _groups.removeWhere((g) => g.id == group.id);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting group: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(Group group, String memberId) async {
    // Show confirmation dialog
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove != true || !mounted) return;

    try {
      // Remove the member ID from the group's member_ids array
      final updatedMemberIds = group.memberIds.where((id) => id != memberId).toList();
      
      await _supabase
          .from('groups')
          .update({
            'member_ids': updatedMemberIds,
          })
          .eq('id', group.id);

      if (mounted) {
        // Schedule reload for next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadGroups();
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}

class AddGroupDialog extends StatefulWidget {
  @override
  _AddGroupDialogState createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends State<AddGroupDialog> {
  final _groupNameController = TextEditingController();
  final List<User> _selectedUsers = [];

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _showUserSelectionDialog() async {
    final result = await showDialog<User>(
      context: context,
      builder: (context) => AddMemberDialog(),
    );
    
    if (result != null) {
      setState(() {
        _selectedUsers.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Group'),
      content: SingleChildScrollView(
        child: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Members:'),
              const SizedBox(height: 8),
              if (_selectedUsers.isNotEmpty)
                Container(
                  constraints: BoxConstraints(
                    maxHeight: 200,
                  ),
                  child: Column(
                    children: _selectedUsers.map((user) => ListTile(
                      title: Text(user.email),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle),
                        onPressed: () {
                          setState(() {
                            _selectedUsers.remove(user);
                          });
                        },
                      ),
                    )).toList(),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _showUserSelectionDialog,
                child: const Text('Add Member'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_groupNameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _groupNameController.text,
                'selectedUsers': _selectedUsers,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class AddMemberDialog extends StatefulWidget {
  @override
  _AddMemberDialogState createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _supabase = Supabase.instance.client;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isNewMember = true;
  bool _searchingUser = false;
  bool _loading = false;
  List<Map<String, dynamic>> _foundUsers = [];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Member',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('New Member')),
                        ButtonSegment(value: false, label: Text('Existing User')),
                      ],
                      selected: {_isNewMember},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _isNewMember = newSelection.first;
                          _foundUsers.clear();
                          _firstNameController.clear();
                          _lastNameController.clear();
                          _emailController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isNewMember) ...[
                              TextField(
                                controller: _firstNameController,
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ] else ...[
                              TextField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Search by email',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _searchUsers,
                              ),
                              if (_searchingUser)
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                ),
                              if (_foundUsers.isNotEmpty)
                                ...(_foundUsers.map((user) => ListTile(
                                  title: Text('${user['first_name']} ${user['last_name']}'),
                                  subtitle: Text(user['email'] ?? ''),
                                  onTap: () => _handleExistingUser(user),
                                )).toList()),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        if (_isNewMember)
                          TextButton(
                            onPressed: _handleAddMember,
                            child: const Text('Next'),
                          ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchUsers(String email) async {
    if (email.isEmpty) {
      setState(() {
        _foundUsers = [];
        _searchingUser = false;
      });
      return;
    }

    setState(() => _searchingUser = true);

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .ilike('email', '%$email%')
          .limit(5);

      setState(() {
        _foundUsers = List<Map<String, dynamic>>.from(response);
        _searchingUser = false;
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
      setState(() => _searchingUser = false);
    }
  }

  void _handleAddMember() async {
    if (_firstNameController.text.isEmpty) return;
    
    try {
      // Store the current context
      final dialogContext = context;
      
      setState(() => _loading = true);
      
      // Show preferences screen
      final preferences = await Navigator.of(dialogContext).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => PreferencesScreen(
            isUserPreferences: false,
            initialPreferences: {
              'dietary_requirements': [],
              'restaurant_preferences': [],
              'location_preferences': [],
              'excluded_cuisines': [],
            },
            onPreferencesSaved: (prefs) {
              Navigator.of(context).pop(prefs);
            },
          ),
        ),
      );

      if (!mounted) return;
      
      if (preferences == null) {
        setState(() => _loading = false);
        return;
      }
      
      try {
        // First create a profile for the new member
        final response = await _supabase.from('profiles').insert({
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'email': _emailController.text,
          'dietary_requirements': preferences['dietary_requirements'] ?? [],
          'restaurant_preferences': preferences['restaurant_preferences'] ?? [],
          'location_preferences': preferences['location_preferences'] ?? [],
          'excluded_cuisines': preferences['excluded_cuisines'] ?? [],
        }).select().single();

        if (!mounted) return;

        // Create User object with the new profile's ID
        final user = User(
          id: response['id'],
          email: response['email'] ?? '',
          firstName: response['first_name'],
          lastName: response['last_name'],
        );
        
        // Pop the dialog with the new user
        Navigator.of(dialogContext).pop(user);
        
      } catch (e) {
        debugPrint('Error creating member profile: $e');
        if (!mounted) return;
        
        setState(() => _loading = false);
        
        // Show error dialog
        await showDialog(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create member: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close error dialog
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in preferences screen: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _handleExistingUser(Map<String, dynamic> userData) {
    if (!mounted) return;
    
    final user = User(
      id: userData['id'],
      email: userData['email'] ?? '',
      firstName: userData['first_name'],
      lastName: userData['last_name'],
    );
    
    Navigator.pop(context, user);
  }
}

class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
  });

  String get name => [firstName, lastName]
      .where((s) => s != null && s.isNotEmpty)
      .join(' ');
} 