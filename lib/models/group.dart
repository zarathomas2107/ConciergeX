class GroupMember {
  final String id;
  final String name;
  final String? email;
  final List<String> dietaryRequirements;
  final List<String> restaurantPreferences;  // e.g., ["Italian", "Japanese", "Fine Dining"]
  final List<String> locationPreferences;    // e.g., ["Covent Garden", "Soho"]
  final bool isUser;

  GroupMember({
    required this.id,
    required this.name,
    this.email,
    this.dietaryRequirements = const [],
    this.restaurantPreferences = const [],
    this.locationPreferences = const [],
    this.isUser = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'dietary_requirements': dietaryRequirements,
    'restaurant_preferences': restaurantPreferences,
    'location_preferences': locationPreferences,
    'is_user': isUser,
  };

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    dietaryRequirements: List<String>.from(json['dietary_requirements'] ?? []),
    restaurantPreferences: List<String>.from(json['restaurant_preferences'] ?? []),
    locationPreferences: List<String>.from(json['location_preferences'] ?? []),
    isUser: json['is_user'] ?? false,
  );
}

class Group {
  final String id;
  final String name;
  final String ownerId;
  final List<GroupMember> members;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'owner_id': ownerId,
    'members': members.map((m) => m.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
  };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'],
    name: json['name'],
    ownerId: json['owner_id'],
    members: (json['group_members'] as List?)?.map((m) => 
      GroupMember.fromJson(m as Map<String, dynamic>)
    ).toList() ?? [],
    createdAt: DateTime.parse(json['created_at']),
  );
} 