import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'create_event_screen.dart';
import 'manage_event_screen.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final club = context.watch<AuthProvider>().userProfile?.club;
    final firestore = context.read<FirestoreService>();

    if (club == null) {
      return const Scaffold(body: Center(child: Text('No club assigned to this account.')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(club)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateEventScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.organizerEvents(club: club),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          if (events.isEmpty) {
            return const Center(child: Text('No events yet. Tap "New Event" to create one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                child: ListTile(
                  title: Text(event.title),
                  subtitle: Text(
                    '${event.venue} · ${event.registeredCount}/${event.capacity} registered · '
                    '${event.checkedInCount} checked in',
                  ),
                  trailing: _StatusBadge(status: event.status),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ManageEventScreen(event: event)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final EventStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      EventStatus.draft => (Colors.grey, 'Draft'),
      EventStatus.published => (Colors.green, 'Published'),
      EventStatus.concluded => (Colors.orange, 'Concluded'),
      EventStatus.archived => (Colors.blueGrey, 'Archived'),
    };
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
