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

  String get formattedDistance {
    if (distance == null) return 'Distance unknown';
    if (distance! < 1000) {
      return '${distance!.round()}m';
    } else {
      return '${(distance! / 1000).toStringAsFixed(1)}km';
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
    double? parseDistance() {
      if (json['Distance'] != null) return (json['Distance'] as num).toDouble();
      if (json['distance'] != null) return (json['distance'] as num).toDouble();
      if (json['distance_meters'] != null) return (json['distance_meters'] as num).toDouble();
      return null;
    }

    return Restaurant(
      restaurantId: json['RestaurantID'] as String? ?? json['restaurant_id'] as String?,
      name: json['Name'] as String? ?? json['name'] as String,
      cuisineType: json['CuisineType'] as String? ?? json['cuisine_type'] as String?,
      address: json['Address'] as String? ?? json['address'] as String,
      rating: ((json['Rating'] ?? json['rating']) as num).toDouble(),
      latitude: ((json['Latitude'] ?? json['latitude']) as num).toDouble(),
      longitude: ((json['Longitude'] ?? json['longitude']) as num).toDouble(),
      priceLevel: json['PriceLevel'] != null ? (json['PriceLevel'] as num).toInt() : 
                 json['price_level'] != null ? (json['price_level'] as num).toInt() : null,
      distance: parseDistance(),
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