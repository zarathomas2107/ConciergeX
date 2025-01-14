import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class Restaurant {
  final String id;
  final String name;
  final List<String> cuisineTypes;
  final double rating;
  final String? address;
  final double latitude;
  final double longitude;
  final double? distance;
  final int? priceLevel;
  final String? area;
  final List<AvailabilitySlot>? availableSlots;
  final String? vegetarianScale;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisineTypes,
    required this.rating,
    this.address,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.priceLevel,
    this.area,
    this.availableSlots,
    this.vegetarianScale,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    final List<dynamic> slots = json['available_slots'] ?? [];
    
    // Handle cuisine_type as a List
    List<String> cuisineTypes;
    if (json['cuisine_type'] is List) {
      cuisineTypes = (json['cuisine_type'] as List).map((e) => e.toString()).toList();
    } else if (json['cuisine_type'] is String) {
      cuisineTypes = (json['cuisine_type'] as String).split(',');
    } else {
      cuisineTypes = ['Unknown'];
    }

    // Handle price_level which can be -1
    int? priceLevel = json['price_level'] == -1 ? null : json['price_level'] as int?;

    final vegetarianScale = json['vegetarian_scale']?.toString();

    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      cuisineTypes: cuisineTypes,
      rating: (json['rating'] as num).toDouble(),
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distance: (json['distance'] as num?)?.toDouble(),
      priceLevel: priceLevel,
      area: json['area'] as String?,
      availableSlots: slots.map((slot) => AvailabilitySlot.fromJson(slot)).toList(),
      vegetarianScale: vegetarianScale,
    );
  }

  factory Restaurant.fromSupabase(Map<String, dynamic> json) => Restaurant.fromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cuisine_type': cuisineTypes.isEmpty ? ['Unknown'] : cuisineTypes,
      'rating': rating,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'distance_meters': distance,
      'price_level': priceLevel,
      'area': area,
    };
  }

  String getPriceLevel() {
    if (priceLevel == null) return '£';
    return '£' * priceLevel!.clamp(1, 4);
  }

  List<AvailabilitySlot>? getAvailableSlotsInRange(
    DateTime startDate,
    DateTime endDate,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) {
    if (availableSlots == null || availableSlots!.isEmpty) {
      return null;
    }
    
    // Use default time range (07:00-22:00) if no specific times provided by API
    final useDefaultTime = startTime.hour == 0 && startTime.minute == 0 && endTime.hour == 23 && endTime.minute == 59;
    final effectiveStartTime = useDefaultTime ? const TimeOfDay(hour: 7, minute: 0) : startTime;
    final effectiveEndTime = useDefaultTime ? const TimeOfDay(hour: 22, minute: 0) : endTime;
    
    // Convert TimeOfDay to minutes for comparison
    final startMinutes = effectiveStartTime.hour * 60 + effectiveStartTime.minute;
    final endMinutes = effectiveEndTime.hour * 60 + effectiveEndTime.minute;
    
    final filtered = availableSlots!.where((slot) {
      final slotDate = DateTime(slot.date.year, slot.date.month, slot.date.day);
      final slotMinutes = slot.timeSlot.hour * 60 + slot.timeSlot.minute;
      
      // Check if date is within range
      final isDateInRange = !slotDate.isBefore(startDate) && !slotDate.isAfter(endDate);
      if (!isDateInRange) {
        return false;
      }
      
      // Check if time is within range
      final isTimeInRange = slotMinutes >= startMinutes && slotMinutes <= endMinutes;
      if (!isTimeInRange) {
        return false;
      }
      
      return true;
    }).toList();

    return filtered;
  }

  String get photoUrl {
    if (id.isEmpty) return '';
    return 'https://ryvqoavkltzagedrvymy.supabase.co/storage/v1/object/public/Photos/London_Restaurant_Photos/$id.jpg';
  }
}

class AvailabilitySlot {
  final DateTime date;
  final TimeOfDay timeSlot;
  final String uuid;

  AvailabilitySlot({
    required this.date,
    required this.timeSlot,
    required this.uuid,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date']?.toString();
    final timeStr = json['time_slot']?.toString();
    final uuid = json['uuid']?.toString();
    
    if (dateStr == null || timeStr == null || uuid == null) {
      throw FormatException('Missing required fields in slot data: $json');
    }
    
    try {
      final date = DateTime.parse(dateStr);
      
      // Parse time in HH:MM:SS format
      final timeParts = timeStr.split(':');
      if (timeParts.length < 2) {
        throw FormatException('Invalid time format: $timeStr');
      }
      
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      return AvailabilitySlot(
        date: date,
        timeSlot: TimeOfDay(hour: hour, minute: minute),
        uuid: uuid,
      );
    } catch (e) {
      rethrow;
    }
  }

  String formatTimeSlot() {
    return '${timeSlot.hour.toString().padLeft(2, '0')}:${timeSlot.minute.toString().padLeft(2, '0')}';
  }
}