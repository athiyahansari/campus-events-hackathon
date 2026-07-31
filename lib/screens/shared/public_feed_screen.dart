import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/theme_provider.dart';
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
    final query = _searchController.text.toLowerCase();
    
    return events.where((e) {
      if (_categoryFilter != null && e.category != _categoryFilter) return false;
      if (!_matchesTimeframe(e, now)) return false;
      if (query.isNotEmpty && !e.title.toLowerCase().contains(query) && !e.venue.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.publicEventFeed(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEvents = snapshot.data!;
          final filteredEvents = _applyFilters(allEvents);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFF1E2F4D),
                title: const Row(
                  children: [
                    Icon(Icons.event_note, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('UniEvents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.dataset, color: Colors.orangeAccent),
                    tooltip: 'Seed Demo Events',
                    onPressed: () async {
                      await context.read<FirestoreService>().seedDemoData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Demo Events (Live, Upcoming & Archived) created!')),
                        );
                      }
                    },
                  ),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) => IconButton(
                      icon: Icon(
                        themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: Colors.white,
                      ),
                      tooltip: 'Toggle Theme',
                      onPressed: () => themeProvider.toggleTheme(),
                    ),
                  ),
                ],
                floating: true,
                pinned: false,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: Icons.calendar_month,
                          iconColor: Colors.blueAccent,
                          count: '${allEvents.length}',
                          label: 'Upcoming\nEvents',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: _StatBox(
                          icon: Icons.folder,
                          iconColor: Colors.orange,
                          count: '3', // Mock for UI demo
                          label: 'Past\nEvents',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: _StatBox(
                          icon: Icons.people,
                          iconColor: Colors.purple,
                          count: '1,378', // Mock for UI demo
                          label: 'Registrations',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search events, venues, organisers...',
                              prefixIcon: Icon(Icons.search, color: Colors.black45),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All',
                                isSelected: _categoryFilter == null && _timeframe == _Timeframe.all,
                                onTap: () => setState(() {
                                  _categoryFilter = null;
                                  _timeframe = _Timeframe.all;
                                }),
                              ),
                              ...kCampusCategories.map((c) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FilterChip(
                                  label: c,
                                  isSelected: _categoryFilter == c,
                                  onTap: () => setState(() {
                                    if (_categoryFilter == c) {
                                      _categoryFilter = null;
                                    } else {
                                      _categoryFilter = c;
                                    }
                                  }),
                                ),
                              )),
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FilterChip(
                                  label: 'Today',
                                  isSelected: _timeframe == _Timeframe.today,
                                  onTap: () => setState(() {
                                    if (_timeframe == _Timeframe.today) {
                                      _timeframe = _Timeframe.all;
                                    } else {
                                      _timeframe = _Timeframe.today;
                                    }
                                  }),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FilterChip(
                                  label: 'This Week',
                                  isSelected: _timeframe == _Timeframe.thisWeek,
                                  onTap: () => setState(() {
                                    if (_timeframe == _Timeframe.thisWeek) {
                                      _timeframe = _Timeframe.all;
                                    } else {
                                      _timeframe = _Timeframe.thisWeek;
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (filteredEvents.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No events found matching your filters.', style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = filteredEvents[index];
                      return EventCard(
                        event: event,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
                        ),
                      );
                    },
                    childCount: filteredEvents.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E2F4D))),
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: Colors.black54, height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3366FF) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
