class GroupMember {
  final String id;
  final String name;
  final List<String> dietaryRequirements;
  final List<String> restaurantPreferences;
  final List<String> locationPreferences;

  GroupMember({
    required this.id,
    required this.name,
    required this.dietaryRequirements,
    required this.restaurantPreferences,
    required this.locationPreferences,
  });
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
} 