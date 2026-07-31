import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/clubs.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/event_card.dart';
import 'event_detail_screen.dart';

enum _Timeframe { all, today, thisWeek }

class PublicFeedScreen extends StatefulWidget {
  /// When nested inside the organizer's TabBarView the surrounding shell already
  /// provides an AppBar, so this screen must not draw its own.
  final bool embedded;

  const PublicFeedScreen({super.key, this.embedded = false});

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  String? _categoryFilter;
  _Timeframe _timeframe = _Timeframe.all;
  final TextEditingController _searchController = TextEditingController();

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

  List<EventModel> _applyFilters(List<EventModel> events) {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();

    return events.where((e) {
      if (_categoryFilter != null && e.category != _categoryFilter) return false;
      if (!_matchesTimeframe(e, now)) return false;
      if (query.isNotEmpty &&
          !e.title.toLowerCase().contains(query) &&
          !e.venue.toLowerCase().contains(query) &&
          !e.category.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _categoryFilter != null || _timeframe != _Timeframe.all || _searchController.text.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _timeframe = _Timeframe.all;
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final p = context.palette;
    final isGuest = context.watch<AuthProvider>().status != AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: p.background,
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.publicEventFeed(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'We could not reach the events service. Check your connection and try again.',
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEvents = snapshot.data!;
          final filteredEvents = _applyFilters(allEvents);

          return RefreshIndicator(
            onRefresh: () async {
              // Firestore streams are already live; this just gives users the
              // expected pull-to-refresh affordance and re-runs the filters.
              await Future<void>.delayed(const Duration(milliseconds: 400));
              if (mounted) setState(() {});
            },
            child: CustomScrollView(
              slivers: [
                if (!widget.embedded)
                  SliverAppBar(
                    floating: true,
                    title: Row(
                      children: [
                        Icon(Icons.event_note, color: p.accent),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('UniEvents'),
                      ],
                    ),
                    actions: [
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) => IconButton(
                          icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                          tooltip: themeProvider.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
                          onPressed: themeProvider.toggleTheme,
                        ),
                      ),
                    ],
                  ),
                if (isGuest) const SliverToBoxAdapter(child: _GuestBanner()),
                SliverToBoxAdapter(child: _FeedStats(publishedEvents: allEvents)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search events, venues, categories…',
                              prefixIcon: Icon(Icons.search, color: p.textSecondary),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: Icon(Icons.close, color: p.textSecondary),
                                      tooltip: 'Clear search',
                                      onPressed: () => setState(() => _searchController.clear()),
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                AppFilterChip(
                                  label: 'All',
                                  isSelected: _categoryFilter == null && _timeframe == _Timeframe.all,
                                  onTap: _clearFilters,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppFilterChip(
                                  label: 'Today',
                                  isSelected: _timeframe == _Timeframe.today,
                                  onTap: () => setState(() => _timeframe =
                                      _timeframe == _Timeframe.today ? _Timeframe.all : _Timeframe.today),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppFilterChip(
                                  label: 'This Week',
                                  isSelected: _timeframe == _Timeframe.thisWeek,
                                  onTap: () => setState(() => _timeframe =
                                      _timeframe == _Timeframe.thisWeek ? _Timeframe.all : _Timeframe.thisWeek),
                                ),
                                for (final c in kCampusCategories) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  AppFilterChip(
                                    label: c,
                                    isSelected: _categoryFilter == c,
                                    onTap: () =>
                                        setState(() => _categoryFilter = _categoryFilter == c ? null : c),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (filteredEvents.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: allEvents.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.event_busy,
                            title: 'No events published yet',
                            message: 'Once an organizer publishes an event it will show up here.',
                          )
                        : AppEmptyState(
                            icon: Icons.search_off,
                            title: 'No events match your filters',
                            message: 'Try a different category, timeframe, or search term.',
                            actionLabel: _hasActiveFilters ? 'Clear filters' : null,
                            onAction: _hasActiveFilters ? _clearFilters : null,
                          ),
                  )
                else
                  SliverList.builder(
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return EventCard(
                        event: event,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: p.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: p.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 18, color: p.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                "You're browsing as a guest — log in to register for events.",
                style: TextStyle(fontSize: 12, color: p.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real counts derived from Firestore. These were previously hardcoded to
/// "3" past events and "1,378" registrations — an obvious tell during a demo.
class _FeedStats extends StatelessWidget {
  final List<EventModel> publishedEvents;

  const _FeedStats({required this.publishedEvents});

  String _compact(int n) {
    if (n < 1000) return '$n';
    final thousands = n / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}k';
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final p = context.palette;
    final now = DateTime.now();
    final upcoming = publishedEvents.where((e) => e.endTime.isAfter(now)).length;

    return StreamBuilder<List<EventModel>>(
      stream: firestore.archivedEvents(),
      builder: (context, snapshot) {
        final archived = snapshot.data ?? const <EventModel>[];
        final registrations = [...publishedEvents, ...archived]
            .fold<int>(0, (sum, e) => sum + e.registeredCount);

        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.calendar_month,
                  iconColor: p.info,
                  count: '$upcoming',
                  label: 'Upcoming',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatBox(
                  icon: Icons.folder_outlined,
                  iconColor: p.warning,
                  count: '${archived.length}',
                  label: 'Past',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatBox(
                  icon: Icons.people_outline,
                  iconColor: p.highlight,
                  count: _compact(registrations),
                  label: 'Registrations',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String count;
  final String label;

  const _StatBox({required this.icon, required this.iconColor, required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: p.textPrimary)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: p.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
