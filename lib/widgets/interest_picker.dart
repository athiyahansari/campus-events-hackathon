import 'package:flutter/material.dart';

import '../utils/clubs.dart';

class InterestPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const InterestPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kCampusCategories.map((category) {
        final isSelected = selected.contains(category);
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (checked) {
            final next = Set<String>.from(selected);
            if (checked) {
              next.add(category);
            } else {
              next.remove(category);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}
