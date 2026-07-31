import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/firestore_service.dart';
import 'archive_event_screen.dart';
import 'checkin_display_screen.dart';
import 'create_event_screen.dart';

class ManageEventScreen extends StatelessWidget {
  final EventModel event;

  const ManageEventScreen({super.key, required this.event});

  Future<void> _updateStatus(BuildContext context, EventStatus status) async {
    await context.read<FirestoreService>().updateEvent(event.id, {
      'status': eventStatusToString(status),
    });
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, y · h:mm a');
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
        actions: [
          if (event.status == EventStatus.draft || event.status == EventStatus.published)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Event',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CreateEventScreen(existingEvent: event)),
              ),
            ),
        ],
      ),
      body: StreamBuilder<EventModel?>(
        stream: firestore.watchEvent(event.id),
        initialData: event,
        builder: (context, snapshot) {
          final current = snapshot.data ?? event;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(current.venue, style: Theme.of(context).textTheme.titleMedium),
              Text(dateFormat.format(current.startTime)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: 'Capacity', value: '${current.capacity}'),
                  _Stat(label: 'Registered', value: '${current.registeredCount}'),
                  _Stat(label: 'Checked in', value: '${current.checkedInCount}'),
                ],
              ),
              const SizedBox(height: 24),
              if (current.status == EventStatus.draft)
                FilledButton.icon(
                  icon: const Icon(Icons.publish),
                  label: const Text('Publish Event'),
                  onPressed: () => _updateStatus(context, EventStatus.published),
                ),
              if (current.status == EventStatus.published || current.status == EventStatus.concluded) ...[
                if (DateTime.now().isAfter(current.endTime)) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Concluded - Needs Archiving',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.archive),
                    label: const Text('Archive Event'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ArchiveEventScreen(event: current)),
                    ),
                  ),
                ] else ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Start Check-In Session'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CheckinDisplayScreen(event: current)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_available),
                    label: const Text('Mark as Concluded'),
                    onPressed: () => _updateStatus(context, EventStatus.concluded),
                  ),
                ],
              ],
              if (current.status == EventStatus.archived) ...[
                const Divider(height: 32),
                Text('Archive Summary', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(current.archiveSummary ?? ''),
                const SizedBox(height: 12),
                Text('${current.archivePhotos.length} photo(s) archived'),
              ],
              const Divider(height: 32),
              Text('Registered Students', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              StreamBuilder<List<RegistrationModel>>(
                stream: firestore.eventRegistrations(current.id),
                builder: (context, regSnapshot) {
                  if (!regSnapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final registrations = regSnapshot.data!;
                  if (registrations.isEmpty) {
                    return const Text('No one has registered yet.');
                  }
                  return Column(
                    children: registrations.map((r) {
                      return FutureBuilder<String>(
                        future: firestore.fetchUserName(r.userId),
                        builder: (context, nameSnapshot) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              r.checkedIn ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: r.checkedIn ? Colors.green : null,
                            ),
                            title: Text(nameSnapshot.data ?? 'Loading…'),
                            trailing: Text(r.checkedIn ? 'Checked in' : 'Registered'),
                          );
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
