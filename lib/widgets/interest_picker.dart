import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/clubs.dart';
import 'app_widgets.dart';

class InterestPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const InterestPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: kCampusCategories.map((category) {
        final isSelected = selected.contains(category);
        return AppFilterChip(
          label: category,
          isSelected: isSelected,
          onTap: () {
            final next = Set<String>.from(selected);
            if (isSelected) {
              next.remove(category);
            } else {
              next.add(category);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}
