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
  AvailabilitySlot? selectedSlot;

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
    selectedDate = dates.isNotEmpty ? dates.first : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final dates = slotsByDate.keys.toList()..sort();
    
    if (dates.isEmpty) {
      return AlertDialog(
        title: Text('No Availability'),
        content: Text('No available time slots found for ${widget.restaurant.name}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(16),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.restaurant.cuisineTypes.join(' • '),
                        style: TextStyle(
                          fontSize: 14,
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
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: dates.map((date) {
                  final isSelected = date == selectedDate;
                  final dateFormatter = DateFormat('E, MMM d');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedDate = date;
                            selectedSlot = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            dateFormatter.format(date),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[300],
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slotsByDate[selectedDate]?.map((slot) {
                    final hour = slot.timeSlot.hour.toString().padLeft(2, '0');
                    final minute = slot.timeSlot.minute.toString().padLeft(2, '0');
                    final isSelected = selectedSlot == slot;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedSlot = slot;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                isSelected 
                                  ? Theme.of(context).primaryColor 
                                  : Theme.of(context).primaryColor.withOpacity(0.8),
                                isSelected 
                                  ? Theme.of(context).primaryColor.withOpacity(0.8) 
                                  : Theme.of(context).primaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$hour:$minute',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList() ?? [],
                ),
              ),
            ),
            if (selectedSlot != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, selectedSlot);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Booking',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 