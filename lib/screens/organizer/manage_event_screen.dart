import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import 'archive_event_screen.dart';
import 'scan_screen.dart';

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
      appBar: AppBar(title: Text(event.title)),
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
              if (current.status == EventStatus.published) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR to Check In'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ScanScreen(event: current)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_available),
                  label: const Text('Mark as Concluded'),
                  onPressed: () => _updateStatus(context, EventStatus.concluded),
                ),
              ],
              if (current.status == EventStatus.concluded) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR to Check In'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ScanScreen(event: current)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.archive),
                  label: const Text('Archive Event'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ArchiveEventScreen(event: current)),
                  ),
                ),
              ],
              if (current.status == EventStatus.archived) ...[
                const Divider(height: 32),
                Text('Archive Summary', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(current.archiveSummary ?? ''),
                const SizedBox(height: 12),
                Text('${current.archivePhotos.length} photo(s) archived'),
              ],
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
