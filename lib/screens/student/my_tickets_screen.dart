import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/notification_model.dart';
import '../../models/registration_model.dart';
import '../../models/waitlist_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_image_helper.dart';
import '../../widgets/app_widgets.dart';
import '../shared/event_detail_screen.dart';
import '../shared/scan_to_checkin_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final Set<String> _requestingCertificateFor = {};

  Future<void> _requestCertificate(FirestoreService firestore, String eventId, String userId) async {
    setState(() => _requestingCertificateFor.add(eventId));
    try {
      await firestore.requestCertificate(eventId: eventId, userId: userId);
      if (!mounted) return;
      showAppSnack(context, 'Certificate requested — the organizer will follow up.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _requestingCertificateFor.remove(eventId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().firebaseUser?.uid;
    final firestore = context.read<FirestoreService>();
    final p = context.palette;

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: const Text('My Tickets'),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: firestore.userNotifications(userId),
            builder: (context, notifSnapshot) {
              final notifications = notifSnapshot.data ?? [];
              final unread = notifications.where((n) => !n.read).length;
              return IconButton(
                tooltip: 'Notifications',
                icon: Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => _showNotifications(context, firestore, notifications),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: StreamBuilder<List<RegistrationModel>>(
        stream: firestore.userRegistrations(userId),
        builder: (context, regSnapshot) {
          if (regSnapshot.hasError) {
            return AppErrorState(
              message: 'We could not load your tickets. Check your connection and try again.',
              onRetry: () => setState(() {}),
            );
          }
          if (!regSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final registrations = regSnapshot.data!;

          return StreamBuilder<List<WaitlistModel>>(
            stream: firestore.userWaitlistEntries(userId),
            builder: (context, waitlistSnapshot) {
              final waitlisted = waitlistSnapshot.data ?? const <WaitlistModel>[];

              if (registrations.isEmpty && waitlisted.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.confirmation_number_outlined,
                  title: 'No tickets yet',
                  message: 'Register for an event from the Feed and your ticket will appear here.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                  if (mounted) setState(() {});
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  children: [
                    if (registrations.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: AppSectionHeader(
                          title: 'Your tickets',
                          subtitle: '${registrations.length} '
                              'event${registrations.length == 1 ? '' : 's'}',
                        ),
                      ),
                      ...registrations.map(
                        (r) => _TicketCard(
                          registration: r,
                          userId: userId,
                          isRequestingCertificate: _requestingCertificateFor.contains(r.eventId),
                          onRequestCertificate: () => _requestCertificate(firestore, r.eventId, userId),
                        ),
                      ),
                    ],
                    if (waitlisted.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: AppSectionHeader(
                          title: 'On the waitlist',
                          subtitle: "We'll notify you if a seat opens up",
                        ),
                      ),
                      ...waitlisted.map((w) => _WaitlistCard(entry: w)),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showNotifications(
    BuildContext context,
    FirestoreService firestore,
    List<NotificationModel> notifications,
  ) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.textPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                if (notifications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        "You're all caught up.",
                        style: TextStyle(color: p.textSecondary),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => Divider(color: p.border, height: 1),
                      itemBuilder: (context, i) {
                        final n = notifications[i];
                        if (!n.read) firestore.markNotificationRead(n.id);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: (n.read ? p.textSecondary : p.accent).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              n.read ? Icons.notifications_none : Icons.notifications_active,
                              size: 20,
                              color: n.read ? p.textSecondary : p.accent,
                            ),
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.read ? FontWeight.w500 : FontWeight.bold,
                              fontSize: 14,
                              color: p.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            n.body,
                            style: TextStyle(fontSize: 12, color: p.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  final RegistrationModel registration;
  final String userId;
  final bool isRequestingCertificate;
  final VoidCallback onRequestCertificate;

  const _TicketCard({
    required this.registration,
    required this.userId,
    required this.isRequestingCertificate,
    required this.onRequestCertificate,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<EventModel?>(
      stream: firestore.watchEvent(registration.eventId),
      builder: (context, snapshot) {
        final event = snapshot.data;
        if (event == null) return const SizedBox.shrink();

        final now = DateTime.now();
        final hasEnded = event.endTime.isBefore(now);
        final isLive = event.startTime.isBefore(now) && event.endTime.isAfter(now);
        final certificateReady = registration.checkedIn && event.certificateEnabled && hasEnded;

        return AppCard(
          margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          padding: EdgeInsets.zero,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.network(
                        getEventBannerUrl(event.category, event.bannerImageUrl, eventId: event.id),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 64,
                          height: 64,
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
                              if (registration.checkedIn)
                                AppTag(label: 'Checked in', color: p.success, icon: Icons.check_circle)
                              else if (isLive)
                                AppTag(label: 'Live now', color: p.success, icon: Icons.circle)
                              else if (hasEnded)
                                AppTag(label: 'Ended', color: p.textSecondary)
                              else
                                AppTag(label: 'Upcoming', color: p.info, icon: Icons.schedule),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            event.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: p.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${DateFormat('MMM d, h:mm a').format(event.startTime)} · ${event.venue}',
                            style: TextStyle(fontSize: 12, color: p.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.border),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: _buildAction(context, event, hasEnded, certificateReady),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAction(BuildContext context, EventModel event, bool hasEnded, bool certificateReady) {
    final p = context.palette;

    if (certificateReady) {
      if (registration.certificateRequested) {
        return _InlineStatus(
          text: 'Certificate requested',
          color: p.warning,
          icon: Icons.workspace_premium,
        );
      }
      return FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: p.warning),
        icon: isRequestingCertificate
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.workspace_premium, size: 18),
        label: const Text('Request certificate'),
        onPressed: isRequestingCertificate ? null : onRequestCertificate,
      );
    }

    if (registration.checkedIn) {
      return _InlineStatus(text: 'Attendance confirmed', color: p.success, icon: Icons.verified);
    }

    if (hasEnded) {
      return _InlineStatus(text: 'You did not check in', color: p.textSecondary, icon: Icons.event_busy);
    }

    return FilledButton.icon(
      icon: const Icon(Icons.qr_code_scanner, size: 18),
      label: const Text('Scan to check in'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ScanToCheckinScreen(event: event)),
      ),
    );
  }
}

class _WaitlistCard extends StatelessWidget {
  final WaitlistModel entry;

  const _WaitlistCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<EventModel?>(
      stream: firestore.watchEvent(entry.eventId),
      builder: (context, snapshot) {
        final event = snapshot.data;
        if (event == null) return const SizedBox.shrink();

        return AppCard(
          margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: p.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.hourglass_top, color: p.warning),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: p.textPrimary),
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
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppTag(label: 'Waitlisted', color: p.warning),
            ],
          ),
        );
      },
    );
  }
}

class _InlineStatus extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _InlineStatus({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
