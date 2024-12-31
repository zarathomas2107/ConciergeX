import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import 'member_preferences_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _supabase = Supabase.instance.client;
  List<Group> _groups = [];
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

      // First, get the groups
      final groupsResponse = await _supabase
          .from('groups')
          .select()
          .eq('owner_id', userId);

      if (groupsResponse == null) {
        setState(() {
          _groups = [];
          _loading = false;
        });
        return;
      }

      // Then, for each group, get its members
      final groups = await Future.wait(
        (groupsResponse as List).map((groupData) async {
          try {
            final membersResponse = await _supabase
                .from('group_members')
                .select()
                .eq('group_id', groupData['id']);

            return Group(
              id: groupData['id'],
              name: groupData['name'],
              ownerId: groupData['owner_id'],
              members: (membersResponse as List?)
                  ?.map((m) => GroupMember.fromJson(m))
                  ?.toList() ?? [],
              createdAt: DateTime.parse(groupData['created_at']),
            );
          } catch (e) {
            debugPrint('Error parsing group: $e');
            return null;
          }
        }),
      );

      if (mounted) {
        setState(() {
          _groups = groups.whereType<Group>().toList();
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
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AddGroupDialog(),
    );

    if (name == null || name.isEmpty) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('groups').insert({
        'name': name,
        'owner_id': userId,
      });

      _loadGroups();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating group: $e')),
      );
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
                    subtitle: Text('${group.members.length} members'),
                    children: [
                      // List existing members
                      ...group.members.map((member) => ListTile(
                            title: Text(member.name),
                            subtitle: Text(member.email ?? 'No email'),
                            trailing: IconButton(
                              icon: ImageIcon(
                                const AssetImage('assets/Icons/profile-user.png'),
                                size: 24,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onPressed: () => _editMemberPreferences(group, member),
                            ),
                          )),
                      // Add member button
                      ListTile(
                        leading: ImageIcon(
                          const AssetImage('assets/Icons/add.png'),
                          size: 24,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        title: const Text('Add Member'),
                        onTap: () => _addMember(group),
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
    final memberDetails = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AddMemberDialog(),
    );

    if (memberDetails == null) return;

    try {
      await _supabase.from('group_members').insert({
        'group_id': group.id,
        'name': memberDetails['name'],
        'email': memberDetails['email'],
        'user_id': memberDetails['user_id'],
        'is_user': memberDetails['is_user'] == 'true',
        'dietary_requirements': [],
        'restaurant_preferences': [],
        'location_preferences': [],
      });

      _loadGroups();  // Reload to show new member
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
}

class AddGroupDialog extends StatefulWidget {
  @override
  _AddGroupDialogState createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends State<AddGroupDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Group'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Group Name',
          hintText: 'Enter group name',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AddMemberDialog extends StatefulWidget {
  @override
  _AddMemberDialogState createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _searchingUser = false;
  List<Map<String, dynamic>> _foundUsers = [];
  bool _isNewMember = true;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle between existing user and new member
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('New Member'),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Existing User'),
                ),
              ],
              selected: {_isNewMember},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _isNewMember = newSelection.first;
                  _foundUsers = [];
                  _nameController.clear();
                  _emailController.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            if (_isNewMember) ...[
              // New member form
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter member name',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'Enter member email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ] else ...[
              // Existing user search
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Search by email',
                  hintText: 'Enter user email',
                ),
                onChanged: _searchUsers,
                keyboardType: TextInputType.emailAddress,
              ),
              if (_searchingUser)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_foundUsers.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _foundUsers.length,
                    itemBuilder: (context, index) {
                      final user = _foundUsers[index];
                      return ListTile(
                        title: Text('${user['first_name']} ${user['last_name']}'),
                        subtitle: Text(user['email'] ?? ''),
                        onTap: () {
                          Navigator.pop(context, {
                            'name': '${user['first_name']} ${user['last_name']}',
                            'email': user['email'],
                            'user_id': user['id'],
                            'is_user': true,
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_isNewMember)
          TextButton(
            onPressed: () {
              if (_nameController.text.isEmpty) return;
              Navigator.pop(context, {
                'name': _nameController.text,
                'email': _emailController.text,
                'is_user': false,
              });
            },
            child: const Text('Add'),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
} 