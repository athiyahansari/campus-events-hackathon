import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Historical Archive')),
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.archivedEvents(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          if (events.isEmpty) {
            return const Center(child: Text('No archived events yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) => _ArchivedEventCard(event: events[index]),
          );
        },
      ),
    );
  }
}

class _ArchivedEventCard extends StatelessWidget {
  final EventModel event;

  const _ArchivedEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${event.venue} · ${DateFormat('MMM d, y').format(event.startTime)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (event.archiveSummary != null && event.archiveSummary!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(event.archiveSummary!),
            ],
            if (event.archivePhotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: event.archivePhotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: event.archivePhotos[i],
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        width: 120,
                        height: 90,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
