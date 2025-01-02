import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import 'package:intl/intl.dart';

class AvailabilityDialog extends StatelessWidget {
  final Restaurant restaurant;

  const AvailabilityDialog({
    Key? key,
    required this.restaurant,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Group slots by date
    Map<DateTime, List<AvailabilitySlot>> slotsByDate = {};
    if (restaurant.availableSlots != null) {
      for (var slot in restaurant.availableSlots!) {
        final date = DateTime(slot.date.year, slot.date.month, slot.date.day);
        slotsByDate.putIfAbsent(date, () => []).add(slot);
      }
    }

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    restaurant.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (restaurant.availableSlots?.isEmpty ?? true)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No availability found for the selected dates'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: slotsByDate.length,
                  itemBuilder: (context, index) {
                    final date = slotsByDate.keys.elementAt(index);
                    final slots = slotsByDate[date]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            DateFormat('EEEE, MMMM d, y').format(date),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: slots.map((slot) {
                            return ElevatedButton(
                              onPressed: () {
                                // TODO: Handle slot selection
                                Navigator.of(context).pop({
                                  'date': slot.date,
                                  'time': slot.timeSlot,
                                });
                              },
                              child: Text(
                                slot.timeSlot.format(context),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }).toList(),
                        ),
                        const Divider(height: 24),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
} 