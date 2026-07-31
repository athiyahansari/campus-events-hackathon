import 'package:flutter/material.dart';

import '../models/event_model.dart';

class EventBadgeChip extends StatelessWidget {
  final EventBadge badge;

  const EventBadgeChip({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (badge) {
      EventBadge.liveNow => (Colors.green, 'Live Now', Icons.circle),
      EventBadge.upcoming => (Colors.blueGrey, 'Upcoming', Icons.schedule),
      EventBadge.fullyBooked => (Colors.red, 'Fully Booked', Icons.block),
    };
    return Chip(
      avatar: Icon(icon, size: 14, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
