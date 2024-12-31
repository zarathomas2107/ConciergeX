import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class Restaurant {
  final String id;
  final String name;
  final String cuisineType;
  final String address;
  final double rating;
  final int priceLevel;
  final String businessStatus;
  final double latitude;
  final double longitude;
  final String? website;
  final String city;
  final String country;
  final double? distance;

  String get photoUrl {
    try {
      // Get the public URL for the restaurant's image from Supabase storage
      return Supabase.instance.client.storage
          .from('Photos/London_Restaurant_Photos')  // Updated bucket path
          .getPublicUrl('${id}.jpg');
    } catch (e) {
      print('Error getting photo URL for restaurant $id: $e');
      return 'https://via.placeholder.com/400x300?text=No+Image';
    }
  }

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisineType,
    required this.address,
    required this.rating,
    required this.priceLevel,
    required this.businessStatus,
    required this.latitude,
    required this.longitude,
    this.website,
    required this.city,
    required this.country,
    this.distance,
  });

  factory Restaurant.fromSupabase(Map<String, dynamic> json) {
    return Restaurant(
      id: json['RestaurantID']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      cuisineType: json['CuisineType']?.toString() ?? '',
      address: json['Address']?.toString() ?? '',
      rating: (json['Rating'] ?? 0.0).toDouble(),
      priceLevel: (json['PriceLevel'] ?? 0).toInt(),
      businessStatus: json['BusinessStatus']?.toString() ?? 'UNKNOWN',
      latitude: (json['Latitude'] ?? 0.0).toDouble(),
      longitude: (json['Longitude'] ?? 0.0).toDouble(),
      website: json['website']?.toString(),
      city: json['City']?.toString() ?? '',
      country: json['Country']?.toString() ?? '',
      distance: json['distance']?.toDouble(),
    );
  }

  String getPriceLevel() {
    return '£' * (priceLevel.clamp(0, 4));
  }
}