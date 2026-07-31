import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/clubs.dart';
import '../../utils/event_image_helper.dart';
import 'event_detail_screen.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.archivedEvents(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          final filteredEvents = _categoryFilter == null 
              ? events 
              : events.where((e) => e.category == _categoryFilter).toList();

          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Color(0xFF1E2F4D),
                title: Text('UniEvents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                floating: true,
                pinned: false,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Event Archive',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'A permanent record of all past APIIT campus events.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              isSelected: _categoryFilter == null,
                              onTap: () => setState(() => _categoryFilter = null),
                            ),
                            ...kCampusCategories.map((c) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _FilterChip(
                                    label: c,
                                    isSelected: _categoryFilter == c,
                                    onTap: () => setState(() {
                                      _categoryFilter = _categoryFilter == c ? null : c;
                                    }),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filteredEvents.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No archived events found.', style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _ArchivedEventCard(event: filteredEvents[index]);
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
          color: isSelected ? const Color(0xFF1E2F4D) : Colors.grey.shade200,
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

class _ArchivedEventCard extends StatelessWidget {
  final EventModel event;

  const _ArchivedEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final bannerUrl = getEventBannerUrl(event.category, event.bannerImageUrl);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: bannerUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(event.category, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                              ),
                              Text(
                                '${event.checkedInCount} attended',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Past', style: TextStyle(fontSize: 10, color: Colors.black54)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E2F4D)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                  ],
                ),
                if (event.archiveSummary != null && event.archiveSummary!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.edit_document, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.archiveSummary!,
                            style: const TextStyle(fontSize: 12, color: Colors.green),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
