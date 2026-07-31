import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/clubs.dart';
import '../../utils/event_image_helper.dart';
import '../../widgets/app_widgets.dart';
import 'event_detail_screen.dart';

class ArchiveScreen extends StatefulWidget {
  /// See [PublicFeedScreen.embedded] — suppresses the app bar when nested in
  /// the organizer shell's TabBarView.
  final bool embedded;

  const ArchiveScreen({super.key, this.embedded = false});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.archivedEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'We could not load the archive. Check your connection and try again.',
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          final filteredEvents =
              _categoryFilter == null ? events : events.where((e) => e.category == _categoryFilter).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 400));
              if (mounted) setState(() {});
            },
            child: CustomScrollView(
              slivers: [
                if (!widget.embedded)
                  const SliverAppBar(floating: true, title: Text('UniEvents')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Archive',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: p.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'A permanent record of past campus events.',
                          style: TextStyle(fontSize: 13, color: p.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              AppFilterChip(
                                label: 'All',
                                isSelected: _categoryFilter == null,
                                onTap: () => setState(() => _categoryFilter = null),
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
                if (filteredEvents.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: events.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Nothing archived yet',
                            message: 'Concluded events appear here once an organizer archives them.',
                          )
                        : AppEmptyState(
                            icon: Icons.search_off,
                            title: 'No archived events in this category',
                            actionLabel: 'Show all',
                            onAction: () => setState(() => _categoryFilter = null),
                          ),
                  )
                else
                  SliverList.builder(
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) => _ArchivedEventCard(event: filteredEvents[index]),
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

class _ArchivedEventCard extends StatelessWidget {
  final EventModel event;

  const _ArchivedEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bannerUrl = getEventBannerUrl(event.category, event.bannerImageUrl, eventId: event.id);

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: bannerUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(width: 80, height: 80, color: p.surfaceAlt),
                  errorWidget: (_, _, _) => Container(
                    width: 80,
                    height: 80,
                    color: p.surfaceAlt,
                    child: Icon(Icons.image_not_supported, color: p.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: AppTag(label: event.category, color: p.info)),
                        const SizedBox(width: AppSpacing.sm),
                        AppTag(label: 'Past', color: p.textSecondary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      event.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: p.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${DateFormat('MMM d, yyyy').format(event.startTime)} · ${event.venue}',
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 13, color: p.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${event.checkedInCount} attended',
                          style: TextStyle(fontSize: 12, color: p.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (event.archiveSummary != null && event.archiveSummary!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: p.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: p.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.article_outlined, size: 16, color: p.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      event.archiveSummary!,
                      style: TextStyle(fontSize: 12, color: p.textPrimary, height: 1.4),
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
    );
  }
}
