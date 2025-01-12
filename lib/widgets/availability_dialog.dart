import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import 'package:intl/intl.dart';

class AvailabilityDialog extends StatefulWidget {
  final Restaurant restaurant;
  final List<AvailabilitySlot> availableSlots;

  const AvailabilityDialog({
    Key? key,
    required this.restaurant,
    required this.availableSlots,
  }) : super(key: key);

  @override
  State<AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<AvailabilityDialog> {
  late DateTime selectedDate;
  late final Map<DateTime, List<AvailabilitySlot>> slotsByDate;

  @override
  void initState() {
    super.initState();
    // Group slots by date
    slotsByDate = {};
    for (var slot in widget.availableSlots) {
      final date = DateTime(slot.date.year, slot.date.month, slot.date.day);
      if (!slotsByDate.containsKey(date)) {
        slotsByDate[date] = [];
      }
      slotsByDate[date]!.add(slot);
    }
    
    // Set initial selected date
    final dates = slotsByDate.keys.toList()..sort();
    selectedDate = dates.first;
  }

  @override
  Widget build(BuildContext context) {
    final dates = slotsByDate.keys.toList()..sort();
    
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.restaurant.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.restaurant.cuisineType,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: dates.map((date) {
                  final isSelected = date == selectedDate;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = date;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey[800],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: slotsByDate[selectedDate]!.map((slot) {
                final hour = slot.timeSlot.hour.toString().padLeft(2, '0');
                final minute = slot.timeSlot.minute.toString().padLeft(2, '0');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$hour:$minute',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
} 