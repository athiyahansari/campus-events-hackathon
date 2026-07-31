import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/event_card.dart';
import 'event_detail_screen.dart';

class PublicFeedScreen extends StatelessWidget {
  const PublicFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Campus Events')),
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.publicEventFeed(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          if (events.isEmpty) {
            return const Center(child: Text('No upcoming events yet — check back soon.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return EventCard(
                event: event,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
