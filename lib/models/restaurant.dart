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
  final String? area;
  final List<AvailabilitySlot>? availableSlots;

  String get photoUrl {
    try {
      if (id.isEmpty) {
        return 'https://picsum.photos/400/300';
      }
      
      return 'https://ryvqoavkltzagedrvymy.supabase.co/storage/v1/object/public/Photos/London_Restaurant_Photos/$id.jpg';
    } catch (e) {
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
    this.area,
    this.availableSlots,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // Handle available_slots parsing
    List<AvailabilitySlot>? slots;
    var slotsData = json['available_slots'];
    
    if (slotsData != null) {
      try {
        // If slotsData is a string, try to decode it
        if (slotsData is String) {
          slotsData = jsonDecode(slotsData);
        }
        
        // Now slotsData should be a List
        if (slotsData is List) {
          slots = slotsData.map((slotData) {
            if (slotData is Map<String, dynamic>) {
              return AvailabilitySlot.fromJson(slotData);
            }
            return null;
          }).whereType<AvailabilitySlot>().toList();
        } else {
          slots = [];
        }
      } catch (e) {
        slots = [];
      }
    } else {
      slots = [];
    }

    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      priceLevel: json['price_level'] as int?,
      cuisineType: json['cuisine_type'] as String? ?? 'Unknown',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distance: (json['distance'] as num?)?.toDouble(),
      area: json['area'] as String?,
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
    
    debugPrint('Filtering slots for $name - Total slots: ${availableSlots!.length}');
    debugPrint('Date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
    debugPrint('Time range: ${startTime.hour}:${startTime.minute} to ${endTime.hour}:${endTime.minute}');
    
    // Normalize dates to start/end of day
    final startDateTime = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateTime = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    
    // Convert TimeOfDay to minutes for comparison
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    
    final filtered = availableSlots!.where((slot) {
      // Normalize the slot date to start of day for comparison
      final slotDate = DateTime(slot.date.year, slot.date.month, slot.date.day);
      final slotMinutes = slot.timeSlot.hour * 60 + slot.timeSlot.minute;
      
      // Check if date is within range (inclusive)
      final isDateInRange = !slotDate.isBefore(startDateTime) && !slotDate.isAfter(endDateTime);
      if (!isDateInRange) {
        debugPrint('Slot date ${slotDate.toIso8601String()} outside range');
        return false;
      }
      
      // Check if time is within range (inclusive)
      final isTimeInRange = slotMinutes >= startMinutes && slotMinutes <= endMinutes;
      if (!isTimeInRange) {
        debugPrint('Slot time ${slot.timeSlot.hour}:${slot.timeSlot.minute} ($slotMinutes minutes) outside range ($startMinutes-$endMinutes)');
        return false;
      }
      
      return true;
    }).toList();

    debugPrint('Found ${filtered.length} slots in range for $name');
    return filtered;
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