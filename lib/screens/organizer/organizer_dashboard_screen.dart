import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_image_helper.dart';
import '../../widgets/app_widgets.dart';
import 'checkin_display_screen.dart';
import 'create_event_screen.dart';
import 'manage_event_screen.dart';

class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  State<OrganizerDashboardScreen> createState() => _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  bool _seeding = false;

  Future<void> _seedDemoEvents(String organizerId, String club) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add demo events?'),
        content: Text(
          'This creates three sample events under $club — one happening now, one tomorrow, '
          'and one archived. Useful for populating a demo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _seeding = true);
    try {
      await context.read<FirestoreService>().seedDemoData(organizerId: organizerId, club: club);
      if (!mounted) return;
      showAppSnack(context, 'Three demo events created.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Could not create demo events: $e', isError: true);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile;
    final club = profile?.club;
    final uid = auth.firebaseUser?.uid;
    final firestore = context.read<FirestoreService>();
    final p = context.palette;

    if (club == null || uid == null) {
      return Scaffold(
        backgroundColor: p.background,
        body: const AppEmptyState(
          icon: Icons.badge_outlined,
          title: 'No club assigned',
          message:
              'This organizer account has no club/school attached, so it cannot create events. '
              'Ask an admin to check the account.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateEventScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<EventModel>>(
        stream: firestore.organizerEvents(organizerId: uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Unable to load events: ${snapshot.error}',
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 400));
              if (mounted) setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              children: [
                Text(
                  'Organizer Dashboard',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: p.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.account_balance_outlined, size: 14, color: p.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(club, style: TextStyle(fontSize: 13, color: p.textSecondary)),
                    ),
                    if (profile != null)
                      AppTag(
                        label: profile.organizerApproved ? 'Approved' : 'Pending approval',
                        color: profile.organizerApproved ? p.success : p.warning,
                        icon: profile.organizerApproved ? Icons.verified : Icons.hourglass_top,
                      ),
                  ],
                ),
                if (profile != null && !profile.organizerApproved) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: p.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: p.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: p.warning),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Your account is awaiting admin approval. You can create and save drafts, '
                            'but publishing is locked until approved.',
                            style: TextStyle(fontSize: 12, color: p.textPrimary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _StatsGrid(events: events),
                const SizedBox(height: AppSpacing.xl),
                AppSectionHeader(
                  title: 'Your events',
                  subtitle: events.isEmpty ? null : '${events.length} total',
                ),
                if (events.isEmpty)
                  AppEmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'No events yet',
                    message: 'Create your first event, or drop in a few demo events to explore the app.',
                    actionLabel: _seeding ? 'Creating…' : 'Add demo events',
                    onAction: _seeding ? null : () => _seedDemoEvents(uid, club),
                  )
                else
                  ...events.map((e) => _EventCard(event: e)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<EventModel> events;
  const _StatsGrid({required this.events});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = events.where((e) => e.status == EventStatus.published).length;
    final drafts = events.where((e) => e.status == EventStatus.draft).length;
    final registrations = events.fold(0, (sum, e) => sum + e.registeredCount);
    final checkedIn = events.fold(0, (sum, e) => sum + e.checkedInCount);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.1,
      children: [
        _StatBox(value: '$active', label: 'Published', icon: Icons.podcasts, color: p.success),
        _StatBox(value: '$drafts', label: 'Drafts', icon: Icons.edit_note, color: p.textSecondary),
        _StatBox(value: '$registrations', label: 'Registrations', icon: Icons.people_outline, color: p.info),
        _StatBox(value: '$checkedIn', label: 'Checked in', icon: Icons.how_to_reg, color: p.highlight),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatBox({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: p.border),
        boxShadow: context.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: p.textPrimary),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: p.textSecondary),
                  maxLines: 1,
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

class _EventCard extends StatelessWidget {
  final EventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final isLive = event.status == EventStatus.published &&
        event.startTime.isBefore(now) &&
        event.endTime.isAfter(now);
    final needsArchiving = event.status != EventStatus.archived && event.endTime.isBefore(now);

    final (statusLabel, statusColor) = switch (event.status) {
      _ when isLive => ('Live now', p.success),
      EventStatus.draft => ('Draft', p.textSecondary),
      EventStatus.published => ('Published', p.info),
      EventStatus.concluded => ('Concluded', p.warning),
      EventStatus.archived => ('Archived', p.textSecondary),
    };

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ManageEventScreen(event: event)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedNetworkImage(
              imageUrl: getEventBannerUrl(event.category, event.bannerImageUrl, eventId: event.id),
              width: 68,
              height: 68,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(width: 68, height: 68, color: p.surfaceAlt),
              errorWidget: (_, _, _) => Container(
                width: 68,
                height: 68,
                color: p.surfaceAlt,
                child: Icon(Icons.event, color: p.textSecondary),
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
                    AppTag(label: statusLabel, color: statusColor, icon: isLive ? Icons.circle : null),
                    if (needsArchiving) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppTag(label: 'Needs archiving', color: p.danger),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  event.title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: p.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MMM d, h:mm a').format(event.startTime)} · ${event.venue}',
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 13, color: p.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${event.registeredCount}/${event.capacity}',
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(Icons.how_to_reg, size: 13, color: p.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${event.checkedInCount}',
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                    if (event.status == EventStatus.published) ...[
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CheckinDisplayScreen(event: event)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: p.accent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_2, size: 14, color: p.accent),
                              const SizedBox(width: 4),
                              Text(
                                'Present QR',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: p.textSecondary),
        ],
      ),
    );
  }
}
