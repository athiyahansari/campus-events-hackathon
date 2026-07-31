import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'create_event_screen.dart';
import 'manage_event_screen.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final club = auth.userProfile?.club;
    final uid = auth.firebaseUser?.uid;
    final firestore = context.read<FirestoreService>();

    if (club == null || uid == null) {
      return const Scaffold(body: Center(child: Text('No club assigned to this account.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.organizerEvents(organizerId: uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderSection(club: club),
              const SizedBox(height: 16),
              _StatsGrid(events: events),
              const SizedBox(height: 24),
              if (events.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No events yet. Create one to get started!', style: TextStyle(color: Colors.black54)),
                  ),
                )
              else
                ...events.map((e) => _EventCard(event: e)),
              const SizedBox(height: 64),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String club;
  const _HeaderSection({required this.club});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organizer Dashboard',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Publish, manage, and archive campus events.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('New Event'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3366FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<EventModel> events;
  const _StatsGrid({required this.events});

  @override
  Widget build(BuildContext context) {
    final active = events.where((e) => e.status == EventStatus.published).length;
    final archived = events.where((e) => e.status == EventStatus.archived).length;
    final capacity = events.fold(0, (sum, e) => sum + e.capacity);
    final registrations = events.fold(0, (sum, e) => sum + e.registeredCount);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _StatBox(value: active.toString(), label: 'Active Events'),
        _StatBox(value: archived.toString(), label: 'Archived'),
        _StatBox(value: capacity.toString(), label: 'Total Capacity'),
        _StatBox(value: registrations.toString(), label: 'Registrations'),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D))),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isLive = event.status == EventStatus.published &&
        event.startTime.isBefore(DateTime.now().add(const Duration(hours: 1))) &&
        event.endTime.isAfter(DateTime.now());

    final statusText = isLive ? 'Live Now' : (event.status.name.substring(0, 1).toUpperCase() + event.status.name.substring(1));
    final statusColor = isLive ? Colors.green : (event.status == EventStatus.published ? Colors.blue : Colors.grey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ManageEventScreen(event: event)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: (event.bannerImageUrl != null && event.bannerImageUrl!.isNotEmpty) ? event.bannerImageUrl! : 'https://via.placeholder.com/150',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(event.category, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                if (isLive) ...[
                                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                                  const SizedBox(width: 4),
                                ],
                                Text(statusText, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E2F4D)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('yyyy-MM-dd').format(event.startTime)} · ${event.venue}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ManageEventScreen(event: event)),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Manage', style: TextStyle(color: Colors.black87, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
