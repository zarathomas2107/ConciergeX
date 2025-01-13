import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import 'availability_dialog.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback? onTap;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final Function(List<AvailabilitySlot>)? onAvailabilityCheck;

  const RestaurantCard({
    Key? key,
    required this.restaurant,
    this.onTap,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.onAvailabilityCheck,
  }) : super(key: key);

  void _onTap(BuildContext context) {
    debugPrint('Card tapped for ${restaurant.name}');
    debugPrint('Has date/time params: ${startDate != null && endDate != null && startTime != null && endTime != null}');
    debugPrint('startDate: $startDate');
    debugPrint('endDate: $endDate');
    debugPrint('startTime: $startTime');
    debugPrint('endTime: $endTime');
    debugPrint('onAvailabilityCheck is null: ${onAvailabilityCheck == null}');
    debugPrint('Total available slots: ${restaurant.availableSlots?.length}');
    
    // Only show availability if we have valid date/time parameters
    if (startDate != null && endDate != null && startTime != null && endTime != null) {
      debugPrint('Have valid date/time parameters');
      debugPrint('Date range: ${startDate!.toIso8601String()} to ${endDate!.toIso8601String()}');
      debugPrint('Time range: ${startTime!.format(context)} to ${endTime!.format(context)}');
      
      final availableSlots = restaurant.getAvailableSlotsInRange(
        startDate!,
        endDate!,
        startTime!,
        endTime!,
      );
      
      debugPrint('Found ${availableSlots?.length} filtered slots');
      
      if (availableSlots != null && availableSlots.isNotEmpty) {
        debugPrint('Has valid slots, calling onAvailabilityCheck');
        onAvailabilityCheck?.call(availableSlots);
      } else {
        debugPrint('No available slots to show');
      }
    } else {
      debugPrint('No valid date/time parameters');
      if (onTap != null) {
        onTap!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: () => _onTap(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo section
            SizedBox(
              width: 160,
              height: 400,
              child: Image.network(
                restaurant.photoUrl ?? 'https://via.placeholder.com/800x450?text=No+Image',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.restaurant, size: 50),
                    ),
                  );
                },
              ),
            ),
            // Details section
            Expanded(
              child: Container(
                height: 400,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Restaurant name and price section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              restaurant.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            restaurant.getPriceLevel(),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Cuisine type
                      Text(
                        restaurant.cuisineTypes.join(' • '),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      if (restaurant.cuisineTypes.contains('Vegetarian') &&
                          restaurant.vegetarianScale != null &&
                          restaurant.vegetarianScale != 'Unknown')
                        Row(
                          children: [
                            const Icon(Icons.eco, color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Veg Score: ${restaurant.vegetarianScale}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    restaurant.area ?? 'Unknown location',
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                restaurant.rating.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Distance at the bottom
                      if (restaurant.distance != null)
                        Text(
                          '${(restaurant.distance! / 1000).toStringAsFixed(1)}km',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimeSlotChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const TimeSlotChip({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}