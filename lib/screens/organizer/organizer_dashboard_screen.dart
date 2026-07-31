import 'package:flutter/material.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organizer Dashboard')),
      body: const Center(child: Text('Your club\'s events — coming in Phase 4')),
    );
  }
}
