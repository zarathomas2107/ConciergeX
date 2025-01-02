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
      print('Getting photo for restaurant: $id');
      
      final url = Supabase.instance.client.storage
          .from('Photos/London_Restaurant_Photos')
          .getPublicUrl('$id.jpg');
      
      print('Generated photo URL: $url');
      return url;
    } catch (e) {
      print('Error getting photo URL for restaurant $id: $e');
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
    var slotsJson = json['available_slots'] as List?;
    return Restaurant(
      id: json['RestaurantID']?.toString() ?? '',
      name: json['Name']?.toString() ?? 'Unknown Restaurant',
      cuisineType: json['CuisineType']?.toString() ?? 'Other',
      rating: (json['Rating'] as num?)?.toDouble() ?? 0.0,
      address: json['Address']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      priceLevel: json['PriceLevel'] != null ? (json['PriceLevel'] as num).toInt() : null,
      availableSlots: slotsJson?.map((slot) => AvailabilitySlot.fromJson(slot)).toList(),
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