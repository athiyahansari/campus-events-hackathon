import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../models/waitlist_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'archive_event_screen.dart';
import 'checkin_display_screen.dart';
import 'create_event_screen.dart';

class ManageEventScreen extends StatelessWidget {
  final EventModel event;

  const ManageEventScreen({super.key, required this.event});

  Future<void> _updateStatus(BuildContext context, EventStatus status) async {
    try {
      await context.read<FirestoreService>().updateEvent(event.id, {
        'status': eventStatusToString(status),
      });
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, 'Event marked as ${eventStatusToString(status)}.');
    } catch (e) {
      if (!context.mounted) return;
      showAppSnack(context, 'Could not update event: $e', isError: true);
    }
  }

  Future<void> _releaseSeat(
    BuildContext context,
    FirestoreService firestore,
    String registrationId,
    String studentName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release this seat?'),
        content: Text(
          "$studentName didn't check in. Their seat will be given to the best-matched "
          'student on the waitlist, who will be notified.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Release')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await firestore.releaseNoShowSeat(eventId: event.id, noShowRegistrationId: registrationId);
      if (!context.mounted) return;
      showAppSnack(context, 'Seat released and the best-matched waitlisted student was notified.');
    } catch (e) {
      if (!context.mounted) return;
      showAppSnack(context, 'Could not release seat: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');
    final firestore = context.read<FirestoreService>();
    final organizerApproved = context.watch<AuthProvider>().userProfile?.organizerApproved ?? false;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (event.status == EventStatus.draft || event.status == EventStatus.published)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit event',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CreateEventScreen(existingEvent: event)),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: StreamBuilder<EventModel?>(
        stream: firestore.watchEvent(event.id),
        initialData: event,
        builder: (context, snapshot) {
          final current = snapshot.data ?? event;
          final now = DateTime.now();
          final hasEnded = current.endTime.isBefore(now);
          final hasStarted = current.startTime.isBefore(now);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Overview
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppTag(label: current.category, color: p.info),
                        const SizedBox(width: AppSpacing.sm),
                        AppTag(
                          label: eventStatusToString(current.status),
                          color: switch (current.status) {
                            EventStatus.published => p.success,
                            EventStatus.draft => p.textSecondary,
                            EventStatus.concluded => p.warning,
                            EventStatus.archived => p.textSecondary,
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 15, color: p.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(current.venue, style: TextStyle(fontSize: 13, color: p.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 15, color: p.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            dateFormat.format(current.startTime),
                            style: TextStyle(fontSize: 13, color: p.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Stats
              Row(
                children: [
                  Expanded(child: _Stat(label: 'Capacity', value: '${current.capacity}', color: p.textSecondary)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _Stat(label: 'Registered', value: '${current.registeredCount}', color: p.info)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _Stat(label: 'Checked in', value: '${current.checkedInCount}', color: p.success)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _Stat(label: 'Waitlist', value: '${current.waitlistCount}', color: p.warning)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actions
              if (current.status == EventStatus.draft) ...[
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.publish),
                    label: const Text('Publish event'),
                    onPressed: organizerApproved ? () => _updateStatus(context, EventStatus.published) : null,
                  ),
                ),
                if (!organizerApproved) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: p.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Publishing is locked until an admin approves your organizer account.',
                          style: TextStyle(fontSize: 12, color: p.warning),
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              if (current.status == EventStatus.published || current.status == EventStatus.concluded) ...[
                if (hasEnded) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: p.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: p.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: p.warning, size: 20),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'This event has ended — archive it to publish a recap.',
                            style: TextStyle(color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archive event'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ArchiveEventScreen(event: current)),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Start check-in session'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CheckinDisplayScreen(event: current)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_available),
                      label: const Text('Mark as concluded'),
                      onPressed: () => _updateStatus(context, EventStatus.concluded),
                    ),
                  ),
                ],
              ],

              if (current.status == EventStatus.archived) ...[
                AppSectionHeader(title: 'Archive recap'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.archiveSummary?.isNotEmpty == true
                            ? current.archiveSummary!
                            : 'No summary was written.',
                        style: TextStyle(fontSize: 13, color: p.textPrimary, height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${current.archivePhotos.length} photo(s) archived',
                        style: TextStyle(fontSize: 12, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Attendees
              AppSectionHeader(
                title: 'Registered students',
                subtitle: hasStarted ? 'Release a no-show seat to promote someone from the waitlist' : null,
              ),
              StreamBuilder<List<RegistrationModel>>(
                stream: firestore.eventRegistrations(current.id),
                builder: (context, regSnapshot) {
                  if (regSnapshot.hasError) {
                    return AppCard(
                      child: Text(
                        'Could not load registrations.',
                        style: TextStyle(color: p.danger, fontSize: 13),
                      ),
                    );
                  }
                  if (!regSnapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final registrations = regSnapshot.data!;
                  if (registrations.isEmpty) {
                    return AppCard(
                      child: Row(
                        children: [
                          Icon(Icons.person_off_outlined, color: p.textSecondary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'No one has registered yet.',
                              style: TextStyle(color: p.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < registrations.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.border),
                          _RegistrationTile(
                            registration: registrations[i],
                            canRelease: hasStarted && !registrations[i].checkedIn,
                            onRelease: (name) =>
                                _releaseSeat(context, firestore, registrations[i].id, name),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              if (current.certificateEnabled) ...[
                const SizedBox(height: AppSpacing.xl),
                AppSectionHeader(
                  title: 'Certificate requests',
                  subtitle: 'Checked-in attendees who asked for a participation certificate',
                ),
                StreamBuilder<List<RegistrationModel>>(
                  stream: firestore.eventRegistrations(current.id),
                  builder: (context, certSnapshot) {
                    if (!certSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final requests = certSnapshot.data!.where((r) => r.certificateRequested).toList();
                    if (requests.isEmpty) {
                      return AppCard(
                        child: Row(
                          children: [
                            Icon(Icons.workspace_premium_outlined, color: p.textSecondary),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'No certificate requests yet.',
                                style: TextStyle(color: p.textSecondary, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < requests.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: p.border),
                            _NameTile(
                              userId: requests[i].userId,
                              icon: Icons.workspace_premium,
                              iconColor: p.warning,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              AppSectionHeader(title: 'Waitlist'),
              StreamBuilder<List<WaitlistModel>>(
                stream: firestore.eventWaitlist(current.id),
                builder: (context, waitlistSnapshot) {
                  if (!waitlistSnapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final waitlist = waitlistSnapshot.data!;
                  if (waitlist.isEmpty) {
                    return AppCard(
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_empty, color: p.textSecondary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'No one is on the waitlist.',
                              style: TextStyle(color: p.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < waitlist.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.border),
                          _NameTile(
                            userId: waitlist[i].userId,
                            icon: Icons.hourglass_top,
                            iconColor: p.warning,
                            trailingText: '#${i + 1}',
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: p.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  final RegistrationModel registration;
  final bool canRelease;
  final void Function(String studentName) onRelease;

  const _RegistrationTile({
    required this.registration,
    required this.canRelease,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final firestore = context.read<FirestoreService>();

    return FutureBuilder<String>(
      future: firestore.fetchUserName(registration.userId),
      builder: (context, nameSnapshot) {
        final name = nameSnapshot.data ?? 'Loading…';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (registration.checkedIn ? p.success : p.textSecondary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              registration.checkedIn ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: registration.checkedIn ? p.success : p.textSecondary,
            ),
          ),
          title: Text(
            name,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
          ),
          subtitle: Text(
            registration.checkedIn ? 'Checked in' : 'Registered',
            style: TextStyle(fontSize: 12, color: p.textSecondary),
          ),
          trailing: canRelease
              ? TextButton(
                  onPressed: nameSnapshot.hasData ? () => onRelease(name) : null,
                  style: TextButton.styleFrom(foregroundColor: p.danger),
                  child: const Text('Release'),
                )
              : null,
        );
      },
    );
  }
}

class _NameTile extends StatelessWidget {
  final String userId;
  final IconData icon;
  final Color iconColor;
  final String? trailingText;

  const _NameTile({
    required this.userId,
    required this.icon,
    required this.iconColor,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final firestore = context.read<FirestoreService>();

    return FutureBuilder<String>(
      future: firestore.fetchUserName(userId),
      builder: (context, snapshot) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          title: Text(
            snapshot.data ?? 'Loading…',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
          ),
          trailing: trailingText == null
              ? null
              : Text(
                  trailingText!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: p.textSecondary),
                ),
        );
      },
    );
  }
}
