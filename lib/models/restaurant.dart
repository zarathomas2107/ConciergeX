import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class Restaurant {
  final String id;
  final String name;
  final String cuisineType;
  final double rating;
  final String? address;
  final double latitude;
  final double longitude;
  final double? distance;
  final int? priceLevel;
  final List<AvailabilitySlot>? availableSlots;

  String get photoUrl {
    try {
      debugPrint('Getting photo for restaurant: $id');
      
      if (id.isEmpty) {
        return 'https://picsum.photos/400/300';
      }
      
      final url = 'https://ryvqoavkltzagedrvymy.supabase.co/storage/v1/object/public/Photos/London_Restaurant_Photos/$id.jpg';
      
      debugPrint('Generated photo URL: $url');
      return url;
    } catch (e) {
      debugPrint('Error getting photo URL for restaurant $id: $e');
      return 'https://picsum.photos/400/300';
    }
  }

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisineType,
    required this.rating,
    this.address,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.priceLevel,
    this.availableSlots,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    debugPrint('Parsing restaurant data: $json');
    List<AvailabilitySlot>? slots;
    if (json['available_slots'] != null) {
      try {
        final slotsData = json['available_slots'];
        if (slotsData is String) {
          // Parse JSON string if needed
          final List<dynamic> parsedSlots = jsonDecode(slotsData);
          slots = parsedSlots.map((slot) => AvailabilitySlot.fromJson(slot)).toList();
        } else if (slotsData is List) {
          slots = slotsData.map((slot) => AvailabilitySlot.fromJson(slot)).toList();
        }
        debugPrint('Parsed ${slots?.length ?? 0} availability slots for restaurant ${json['name']}');
      } catch (e) {
        debugPrint('Error parsing availability slots: $e');
        slots = null;
      }
    }

    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Restaurant',
      cuisineType: json['cuisine_type']?.toString() ?? 'Unknown',
      rating: (json['rating'] ?? 0.0).toDouble(),
      address: json['address']?.toString(),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      distance: json['distance_meters']?.toDouble(),
      priceLevel: json['price_level']?.toInt(),
      availableSlots: slots,
    );
  }

  factory Restaurant.fromSupabase(Map<String, dynamic> json) => Restaurant.fromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cuisine_type': cuisineType,
      'rating': rating,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'distance_meters': distance,
      'price_level': priceLevel,
    };
  }

  String getPriceLevel() {
    if (priceLevel == null) return '£';
    return '£' * priceLevel!.clamp(1, 4);
  }
}

class AvailabilitySlot {
  final DateTime date;
  final TimeOfDay timeSlot;

  AvailabilitySlot({
    required this.date,
    required this.timeSlot,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    var dateStr = json['date'] as String;
    var timeStr = json['time_slot'] as String;
    var time = TimeOfDay.fromDateTime(DateTime.parse('2000-01-01 $timeStr'));
    
    return AvailabilitySlot(
      date: DateTime.parse(dateStr),
      timeSlot: time,
    );
  }
}