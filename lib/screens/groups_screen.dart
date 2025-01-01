import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import 'member_preferences_screen.dart';
import 'preferences_screen.dart';
import '../utils/string_extensions.dart';

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

    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AddGroupDialog(),
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('groups').insert({
        'name': name,
        'created_by': userId,
        'member_ids': [userId],
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
          .select()
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
        backgroundColor: Colors.black,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ImageIcon(
              const AssetImage('assets/Icons/profile-user.png'),
              color: Colors.white,
            ),
          ),
        ),
        title: const Text('Groups'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
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
                    children: [
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadMemberDetails(group.memberIds),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text('No members');
                          }
                          return Column(
                            children: snapshot.data!.map((member) => ListTile(
                              title: Text(member['name'] ?? 'Unknown'),
                              subtitle: Text(member['email'] ?? ''),
                            )).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        backgroundColor: Colors.black,
        child: ImageIcon(
          const AssetImage('assets/Icons/add.png'),
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _addMember(Group group) async {
    if (!mounted) return;

    final result = await showDialog<User>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext context) => WillPopScope(
        onWillPop: () async => false,  // Prevent back button from closing dialog
        child: AddMemberDialog(),
      ),
    );
    
    if (result == null || !mounted) return;

    try {
      final updatedMemberIds = [...group.memberIds, result.id];
      
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding member: $e')),
        );
      }
    }
  }

  Future<void> _editMemberPreferences(Group group, GroupMember member) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberPreferencesScreen(
          member: member,
          groupId: group.id,
        ),
      ),
    );
    _loadGroups();  // Reload to show updated preferences
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
              Navigator.pop(context, _groupNameController.text);
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
  List<Map<String, dynamic>> _foundUsers = [];
  bool _searchingUser = false;

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
    
    // Show preferences screen
    final preferences = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PreferencesScreen(
          isUserPreferences: false,
          initialPreferences: {
            'dietary_requirements': [],
            'restaurant_preferences': [],
          },
          onPreferencesSaved: (prefs) => Navigator.pop(context, prefs),
        ),
      ),
    );

    if (preferences == null) return;
    
    final result = <String, dynamic>{
      'name': '${_firstNameController.text} ${_lastNameController.text}'.trim(),
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'email': _emailController.text,
      'is_user': false,
      'dietary_requirements': preferences['dietary_requirements'] ?? [],
      'restaurant_preferences': preferences['restaurant_preferences'] ?? [],
    };
    
    Navigator.pop(context, result);
  }

  void _handleExistingUser(Map<String, dynamic> userData) {
    if (!mounted) return;
    
    final user = User(
      id: userData['id'],
      email: userData['email'] ?? '',
      firstName: userData['first_name'],
      lastName: userData['last_name'],
    );
    
    // Schedule navigation for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(user);
      }
    });
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