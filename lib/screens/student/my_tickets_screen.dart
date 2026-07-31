import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/notification_model.dart';
import '../../models/registration_model.dart';
import '../../models/waitlist_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../shared/scan_to_checkin_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final Set<String> _requestingCertificateFor = {};

  Future<void> _requestCertificate(FirestoreService firestore, String eventId, String userId) async {
    setState(() => _requestingCertificateFor.add(eventId));
    try {
      await firestore.requestCertificate(eventId: eventId, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificate requested! The organizer will follow up.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _requestingCertificateFor.remove(eventId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().firebaseUser?.uid;
    final firestore = context.read<FirestoreService>();

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets'),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: firestore.userNotifications(userId),
            builder: (context, notifSnapshot) {
              final notifications = notifSnapshot.data ?? [];
              final unread = notifications.where((n) => !n.read).length;
              return IconButton(
                icon: Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications),
                ),
                onPressed: () => _showNotifications(context, firestore, notifications),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          StreamBuilder<List<WaitlistModel>>(
            stream: firestore.userWaitlistEntries(userId),
            builder: (context, waitlistSnapshot) {
              final waitlisted = waitlistSnapshot.data ?? [];
              if (waitlisted.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Waitlisted', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ...waitlisted.map((w) {
                    return StreamBuilder<EventModel?>(
                      stream: firestore.watchEvent(w.eventId),
                      builder: (context, eventSnapshot) {
                        final event = eventSnapshot.data;
                        if (event == null) return const SizedBox.shrink();
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.hourglass_top),
                            title: Text(event.title),
                            subtitle: Text(
                              '${event.venue} · ${DateFormat('MMM d, h:mm a').format(event.startTime)}',
                            ),
                            trailing: const Chip(label: Text('Waitlisted')),
                          ),
                        );
                      },
                    );
                  }),
                  const Divider(height: 24),
                ],
              );
            },
          ),
          StreamBuilder<List<RegistrationModel>>(
            stream: firestore.userRegistrations(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final registrations = snapshot.data!;
              if (registrations.isEmpty) {
                return const Center(child: Text('You haven\'t registered for any events yet.'));
              }
              return Column(
                children: registrations.map((registration) {
                  return StreamBuilder<EventModel?>(
                    stream: firestore.watchEvent(registration.eventId),
                    builder: (context, eventSnapshot) {
                      final event = eventSnapshot.data;
                      if (event == null) return const SizedBox.shrink();

                      final certificateAvailable =
                          registration.checkedIn && event.certificateEnabled && !DateTime.now().isBefore(event.endTime);
                      final requestingCertificate = _requestingCertificateFor.contains(event.id);

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
                          trailing: !registration.checkedIn
                              ? FilledButton.icon(
                                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                                  label: const Text('Scan'),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ScanToCheckinScreen(event: event)),
                                  ),
                                )
                              : !certificateAvailable
                                  ? const Chip(label: Text('Checked in'))
                                  : registration.certificateRequested
                                      ? const Chip(
                                          label: Text('Certificate requested'),
                                          avatar: Icon(Icons.workspace_premium, size: 18),
                                        )
                                      : OutlinedButton.icon(
                                          icon: const Icon(Icons.workspace_premium, size: 18),
                                          label: requestingCertificate
                                              ? const SizedBox(
                                                  height: 16,
                                                  width: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Text('Get Certificate'),
                                          onPressed: requestingCertificate
                                              ? null
                                              : () => _requestCertificate(firestore, event.id, userId),
                                        ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNotifications(
    BuildContext context,
    FirestoreService firestore,
    List<NotificationModel> notifications,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (notifications.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No notifications yet.')),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: notifications.map((n) {
              if (!n.read) firestore.markNotificationRead(n.id);
              return ListTile(
                leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active),
                title: Text(n.title),
                subtitle: Text(n.body),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
