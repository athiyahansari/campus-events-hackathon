import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../shared/scan_to_checkin_screen.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().firebaseUser?.uid;
    final firestore = context.read<FirestoreService>();

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Tickets')),
      body: StreamBuilder<List<RegistrationModel>>(
        stream: firestore.userRegistrations(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final registrations = snapshot.data!;
          if (registrations.isEmpty) {
            return const Center(child: Text('You haven\'t registered for any events yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: registrations.length,
            itemBuilder: (context, index) {
              final registration = registrations[index];
              return StreamBuilder<EventModel?>(
                stream: firestore.watchEvent(registration.eventId),
                builder: (context, eventSnapshot) {
                  final event = eventSnapshot.data;
                  if (event == null) return const SizedBox.shrink();
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        registration.checkedIn ? Icons.check_circle : Icons.event_available,
                        color: registration.checkedIn ? Colors.green : null,
                      ),
                      title: Text(event.title),
                      subtitle: Text(
                        '${event.venue} · ${DateFormat('MMM d, h:mm a').format(event.startTime)}',
                      ),
                      trailing: registration.checkedIn
                          ? const Chip(label: Text('Checked in'))
                          : FilledButton.icon(
                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                              label: const Text('Scan'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ScanToCheckinScreen(event: event)),
                              ),
                            ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
