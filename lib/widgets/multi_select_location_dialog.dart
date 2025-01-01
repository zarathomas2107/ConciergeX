import 'package:flutter/material.dart';
import '../utils/string_extensions.dart';

class MultiSelectLocationDialog extends StatefulWidget {
  final Map<String, List<String>> groupedLocations;
  final List<String> currentSelections;

  const MultiSelectLocationDialog({
    Key? key,
    required this.groupedLocations,
    required this.currentSelections,
  }) : super(key: key);

  @override
  State<MultiSelectLocationDialog> createState() => _MultiSelectLocationDialogState();
}

class _MultiSelectLocationDialogState extends State<MultiSelectLocationDialog> {
  late List<String> _selectedLocations;

  @override
  void initState() {
    super.initState();
    _selectedLocations = List.from(widget.currentSelections);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Locations'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: widget.groupedLocations.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      entry.key.toTitleCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...entry.value.map((location) => CheckboxListTile(
                    title: Text(location),
                    value: _selectedLocations.contains(location),
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedLocations.add(location);
                        } else {
                          _selectedLocations.remove(location);
                        }
                      });
                    },
                    dense: true,
                  )),
                  const Divider(),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedLocations),
          child: const Text('Save'),
        ),
      ],
    );
  }
} 