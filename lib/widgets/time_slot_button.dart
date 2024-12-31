import 'package:flutter/material.dart';

class TimeSlotButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const TimeSlotButton({
    Key? key,
    required this.time,
    required this.onTap,
  }) : super(key: key);

  String _formatTime(String time) {
    // If time includes seconds (HH:mm:ss), remove them
    if (time.length == 8) {
      return time.substring(0, 5);
    }
    return time;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF006400),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(_formatTime(time)),
      ),
    );
  }
} 