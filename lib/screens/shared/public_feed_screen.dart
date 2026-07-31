import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/clubs.dart';
import '../../widgets/event_card.dart';
import 'event_detail_screen.dart';

enum _Timeframe { all, today, thisWeek }

class PublicFeedScreen extends StatefulWidget {
  const PublicFeedScreen({super.key});

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  bool _browseAll = false;
  String? _categoryFilter;
  _Timeframe _timeframe = _Timeframe.all;

  bool _matchesTimeframe(EventModel event, DateTime now) {
    switch (_timeframe) {
      case _Timeframe.all:
        return true;
      case _Timeframe.today:
        return event.startTime.year == now.year &&
            event.startTime.month == now.month &&
            event.startTime.day == now.day;
      case _Timeframe.thisWeek:
        return !event.startTime.isBefore(now) && event.startTime.isBefore(now.add(const Duration(days: 7)));
    }
  }

  List<EventModel> _applyFilters(List<EventModel> events, {required bool personalize, required List<String> interests}) {
    final now = DateTime.now();
    return events.where((e) {
      if (personalize && !interests.contains(e.category)) return false;
      if (_categoryFilter != null && e.category != _categoryFilter) return false;
      if (!_matchesTimeframe(e, now)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final firestore = context.read<FirestoreService>();
    final isStudent = auth.status == AuthStatus.authenticated && !auth.isOrganizer;
    final interests = auth.userProfile?.interests ?? const [];
    final personalize = isStudent && !_browseAll;

    return Scaffold(
      appBar: AppBar(title: const Text('Campus Events')),
      body: Column(
        children: [
          if (isStudent)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    personalize ? 'Showing events for your interests' : 'Browsing all events',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      const Text('Browse All'),
                      Switch(
                        value: _browseAll,
                        onChanged: (v) => setState(() => _browseAll = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _categoryFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All categories')),
                      ...kCampusCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() => _categoryFilter = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<_Timeframe>(
                    initialValue: _timeframe,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'When', isDense: true),
                    items: const [
                      DropdownMenuItem(value: _Timeframe.all, child: Text('Any time')),
                      DropdownMenuItem(value: _Timeframe.today, child: Text('Today')),
                      DropdownMenuItem(value: _Timeframe.thisWeek, child: Text('This week')),
                    ],
                    onChanged: (v) => setState(() => _timeframe = v!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EventModel>>(
              stream: firestore.publicEventFeed(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Something went wrong: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = _applyFilters(snapshot.data!, personalize: personalize, interests: interests);

                if (filtered.isEmpty) {
                  return _EmptyState(
                    personalized: personalize,
                    hasExtraFilters: _categoryFilter != null || _timeframe != _Timeframe.all,
                    onBrowseAll: () => setState(() => _browseAll = true),
                    onClearFilters: () => setState(() {
                      _categoryFilter = null;
                      _timeframe = _Timeframe.all;
                    }),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final event = filtered[index];
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
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool personalized;
  final bool hasExtraFilters;
  final VoidCallback onBrowseAll;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.personalized,
    required this.hasExtraFilters,
    required this.onBrowseAll,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final String message;
    final String? actionLabel;
    final VoidCallback? action;

    if (personalized) {
      message = "No events match your interests right now.";
      actionLabel = 'Browse All Events';
      action = onBrowseAll;
    } else if (hasExtraFilters) {
      message = 'No events match these filters.';
      actionLabel = 'Clear Filters';
      action = onClearFilters;
    } else {
      message = 'No upcoming events yet — check back soon.';
      actionLabel = null;
      action = null;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: action, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
