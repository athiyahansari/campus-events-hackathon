import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../models/waitlist_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_image_helper.dart';
import '../../widgets/app_widgets.dart';
import '../auth/login_screen.dart';
import 'scan_to_checkin_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _registering = false;
  bool _requestingCertificate = false;

  Future<void> _requestCertificate(String eventId, String userId) async {
    setState(() => _requestingCertificate = true);
    final firestore = context.read<FirestoreService>();
    try {
      await firestore.requestCertificate(eventId: eventId, userId: userId);
      if (!mounted) return;
      showAppSnack(context, 'Certificate requested — the organizer will follow up.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _requestingCertificate = false);
    }
  }

  Future<void> _register(String eventId, String userId) async {
    setState(() => _registering = true);
    final firestore = context.read<FirestoreService>();
    try {
      final outcome = await firestore.registerForEvent(eventId: eventId, userId: userId);
      if (!mounted) return;
      showAppSnack(
        context,
        outcome == RegistrationOutcome.registered
            ? "You're registered! We'll see you there."
            : "Event is full — you've been added to the waitlist. We'll notify you if a seat opens.",
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    // Watch the event doc rather than rendering the snapshot we were pushed
    // with — otherwise capacity/spots-left stay frozen after registering.
    return StreamBuilder<EventModel?>(
      stream: firestore.watchEvent(widget.event.id),
      initialData: widget.event,
      builder: (context, snapshot) {
        final event = snapshot.data ?? widget.event;
        return _buildScaffold(context, event, firestore);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, EventModel event, FirestoreService firestore) {
    final p = context.palette;
    final auth = context.watch<AuthProvider>();
    final dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');
    final bannerUrl = getEventBannerUrl(event.category, event.bannerImageUrl, eventId: event.id);
    final now = DateTime.now();

    final isLive = event.status == EventStatus.published &&
        event.startTime.isBefore(now) &&
        event.endTime.isAfter(now);
    final hasEnded = event.endTime.isBefore(now);

    final progress = event.capacity > 0 ? (event.registeredCount / event.capacity).clamp(0.0, 1.0) : 0.0;
    final spotsLeft = (event.capacity - event.registeredCount).clamp(0, event.capacity);

    return Scaffold(
      backgroundColor: p.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: p.appBar,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: bannerUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: p.surfaceAlt),
                    errorWidget: (_, _, _) => Container(
                      color: AppBrand.navy,
                      child: const Center(child: Icon(Icons.event, size: 56, color: Colors.white54)),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent, Colors.black87],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: AppSpacing.lg,
                    left: AppSpacing.lg,
                    child: Row(
                      children: [
                        if (isLive)
                          const AppTag(label: 'Live Now', color: Color(0xFF1E8E3E), icon: Icons.circle, solid: true)
                        else if (hasEnded)
                          AppTag(label: 'Ended', color: p.textSecondary, solid: true)
                        else if (event.isFull)
                          AppTag(label: 'Fully Booked', color: p.danger, solid: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTag(label: event.category, color: p.info),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    event.title,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: p.textPrimary, height: 1.25),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _InfoRow(icon: Icons.location_on_outlined, iconColor: p.danger, text: event.venue),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(
                    icon: Icons.calendar_month_outlined,
                    iconColor: p.info,
                    text: dateFormat.format(event.startTime),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(
                    icon: Icons.workspace_premium_outlined,
                    iconColor: p.warning,
                    text: event.certificateEnabled
                        ? 'Participation certificate available'
                        : 'No certificate for this event',
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Capacity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.isFull ? 'Fully booked' : '$spotsLeft of ${event.capacity} spots left',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: event.isFull ? p.danger : p.textPrimary,
                        ),
                      ),
                      Text(
                        '${event.registeredCount} registered',
                        style: TextStyle(fontSize: 13, color: p.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: p.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(event.isFull ? p.danger : p.accent),
                    ),
                  ),
                  if (event.waitlistCount > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(Icons.hourglass_top, size: 14, color: p.warning),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${event.waitlistCount} on the waitlist',
                          style: TextStyle(fontSize: 12, color: p.textSecondary),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'About this event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    event.description,
                    style: TextStyle(fontSize: 15, color: p.textSecondary, height: 1.55),
                  ),

                  if (event.status == EventStatus.archived) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Event recap',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (event.archiveSummary != null && event.archiveSummary!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: p.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: p.success.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          event.archiveSummary!,
                          style: TextStyle(fontSize: 14, color: p.textPrimary, height: 1.5),
                        ),
                      ),
                    if (event.archivePhotos.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: event.archivePhotos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                          itemBuilder: (context, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: CachedNetworkImage(
                              imageUrl: event.archivePhotos[i],
                              width: 160,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(width: 160, height: 120, color: p.surfaceAlt),
                              errorWidget: (_, _, _) => Container(
                                width: 160,
                                height: 120,
                                color: p.surfaceAlt,
                                child: Icon(Icons.image_not_supported, color: p.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // Breathing room so the pinned action bar never covers content.
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _ActionBar(
        child: _buildAction(context, event, auth, firestore),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    EventModel event,
    AuthProvider auth,
    FirestoreService firestore,
  ) {
    final p = context.palette;

    if (auth.status != AuthStatus.authenticated) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Log in to register'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      );
    }

    if (auth.isOrganizer || auth.isAdmin) {
      return _StatusPill(
        text: auth.isAdmin ? 'Viewing as admin' : 'Viewing as organizer',
        color: p.textSecondary,
        icon: Icons.visibility_outlined,
      );
    }

    final userId = auth.firebaseUser!.uid;
    final hasEnded = event.endTime.isBefore(DateTime.now());

    return StreamBuilder<RegistrationModel?>(
      stream: firestore.watchRegistration(eventId: event.id, userId: userId),
      builder: (context, snapshot) {
        final registration = snapshot.data;

        if (registration != null) {
          if (registration.checkedIn) {
            final certificateReady = event.certificateEnabled && hasEnded;
            if (!certificateReady) {
              return _StatusPill(text: 'Checked in', color: p.success, icon: Icons.check_circle);
            }
            if (registration.certificateRequested) {
              return _StatusPill(
                text: 'Certificate requested',
                color: p.warning,
                icon: Icons.workspace_premium,
              );
            }
            return SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: p.warning),
                icon: _requestingCertificate
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.workspace_premium),
                label: const Text('Request certificate'),
                onPressed: _requestingCertificate ? null : () => _requestCertificate(event.id, userId),
              ),
            );
          }

          if (hasEnded) {
            return _StatusPill(text: 'You missed this one', color: p.textSecondary, icon: Icons.event_busy);
          }

          return SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to check in'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ScanToCheckinScreen(event: event)),
              ),
            ),
          );
        }

        return StreamBuilder<WaitlistModel?>(
          stream: firestore.watchWaitlistEntry(eventId: event.id, userId: userId),
          builder: (context, waitlistSnapshot) {
            if (waitlistSnapshot.data != null) {
              return _StatusPill(
                text: "You're on the waitlist",
                color: p.warning,
                icon: Icons.hourglass_top,
              );
            }

            if (hasEnded) {
              return _StatusPill(
                text: 'Registration closed',
                color: p.textSecondary,
                icon: Icons.lock_outline,
              );
            }

            return SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: event.isFull ? p.warning : p.accent),
                onPressed: _registering ? null : () => _register(event.id, userId),
                child: _registering
                    ? const SizedBox(
                        height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(event.isFull ? 'Join waitlist' : 'Register now'),
              ),
            );
          },
        );
      },
    );
  }
}

/// Pinned bottom bar. Wrapped in SafeArea so it clears the gesture bar.
class _ActionBar extends StatelessWidget {
  final Widget child;

  const _ActionBar({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _StatusPill({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoRow({required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: p.textPrimary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
