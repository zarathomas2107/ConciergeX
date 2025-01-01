import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class Restaurant {
  final String? restaurantId;
  final String name;
  final String? cuisineType;
  final String address;
  final double rating;
  final double latitude;
  final double longitude;
  final int? priceLevel;
  final double? distance;

  String get photoUrl {
    try {
      if (restaurantId == null) {
        return 'https://picsum.photos/400/300';
      }
      print('Getting photo for restaurant: $restaurantId');
      
      final url = Supabase.instance.client.storage
          .from('Photos/London_Restaurant_Photos')
          .getPublicUrl('$restaurantId.jpg');
      
      print('Generated photo URL: $url');
      return url;
    } catch (e) {
      print('Error getting photo URL for restaurant $restaurantId: $e');
      return 'https://picsum.photos/400/300';
    }
  }

  Restaurant({
    this.restaurantId,
    required this.name,
    this.cuisineType,
    required this.address,
    required this.rating,
    required this.latitude,
    required this.longitude,
    this.priceLevel,
    this.distance,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      restaurantId: json['RestaurantID'] as String?,
      name: json['Name'] as String,
      cuisineType: json['CuisineType'] as String?,
      address: json['Address'] as String,
      rating: (json['Rating'] as num).toDouble(),
      latitude: (json['Latitude'] as num).toDouble(),
      longitude: (json['Longitude'] as num).toDouble(),
      priceLevel: json['PriceLevel'] != null ? (json['PriceLevel'] as num).toInt() : null,
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
    );
  }

  factory Restaurant.fromSupabase(Map<String, dynamic> json) => Restaurant.fromJson(json);

  Map<String, dynamic> toJson() => {
    'RestaurantID': restaurantId,
    'Name': name,
    'CuisineType': cuisineType,
    'Address': address,
    'Rating': rating,
    'Latitude': latitude,
    'Longitude': longitude,
    'PriceLevel': priceLevel,
    'distance': distance,
  };

  String getPriceLevel() {
    if (priceLevel == null) return '£';
    return '£' * priceLevel!.clamp(1, 4);
  }
}