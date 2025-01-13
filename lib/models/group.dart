class GroupMember {
  final String id;
  final String name;
  final List<String> dietaryRequirements;
  final List<String> restaurantPreferences;
  final List<String> locationPreferences;
  final List<String> excludedCuisines;

  GroupMember({
    required this.id,
    required this.name,
    required this.dietaryRequirements,
    required this.restaurantPreferences,
    required this.locationPreferences,
    required this.excludedCuisines,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'],
      name: json['first_name'] + ' ' + (json['last_name'] ?? ''),
      dietaryRequirements: List<String>.from(json['dietary_requirements'] ?? []),
      restaurantPreferences: List<String>.from(json['restaurant_preferences'] ?? []),
      locationPreferences: List<String>.from(json['location_preferences'] ?? []),
      excludedCuisines: List<String>.from(json['excluded_cuisines'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dietary_requirements': dietaryRequirements,
    'restaurant_preferences': restaurantPreferences,
    'location_preferences': locationPreferences,
    'excluded_cuisines': excludedCuisines,
  };
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