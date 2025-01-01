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
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      memberIds: List<String>.from(json['member_ids'] ?? []),
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
} 