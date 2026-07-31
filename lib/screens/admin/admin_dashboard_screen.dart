import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// The global super admin's home screen: review signed-up accounts, mainly to
/// approve or revoke organizers. An organizer can create events and save drafts
/// as soon as they sign up, but cannot publish until approved here — enforced in
/// firestore.rules, not just this UI.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final p = context.palette;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: p.accent),
              const SizedBox(width: AppSpacing.sm),
              const Text('Admin'),
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
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: () => context.read<AuthProvider>().signOut(),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          bottom: TabBar(
            labelColor: p.onAppBar,
            unselectedLabelColor: p.onAppBar.withValues(alpha: 0.6),
            indicatorColor: p.accent,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.verified_user_outlined, size: 20), text: 'Organizers'),
              Tab(icon: Icon(Icons.school_outlined, size: 20), text: 'Students'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrganizerReviewTab(firestore: firestore),
            _StudentListTab(firestore: firestore),
          ],
        ),
      ),
    );
  }
}

class _OrganizerReviewTab extends StatelessWidget {
  final FirestoreService firestore;

  const _OrganizerReviewTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return StreamBuilder<List<UserModel>>(
      stream: firestore.usersByRole(UserRole.organizer),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(message: 'Could not load organizer accounts: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final organizers = snapshot.data!;
        if (organizers.isEmpty) {
          return const AppEmptyState(
            icon: Icons.badge_outlined,
            title: 'No organizer accounts yet',
            message: 'When someone signs up as an organizer they will appear here for review.',
          );
        }

        // Pending review first — that's the admin's actual job queue.
        final sorted = [...organizers]..sort((a, b) {
            if (a.organizerApproved == b.organizerApproved) return a.name.compareTo(b.name);
            return a.organizerApproved ? 1 : -1;
          });
        final pending = sorted.where((o) => !o.organizerApproved).length;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppSectionHeader(
              title: 'Organizer approvals',
              subtitle: pending == 0
                  ? 'All organizers reviewed'
                  : '$pending account${pending == 1 ? '' : 's'} awaiting review',
              trailing: pending > 0 ? AppTag(label: '$pending pending', color: p.warning) : null,
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: p.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: p.info.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: p.info),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Unapproved organizers can create events and save drafts, but cannot publish '
                      'them to students until you approve their account.',
                      style: TextStyle(fontSize: 12, color: p.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            ...sorted.map((organizer) => _OrganizerCard(organizer: organizer)),
            const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    );
  }
}

class _StudentListTab extends StatelessWidget {
  final FirestoreService firestore;

  const _StudentListTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return StreamBuilder<List<UserModel>>(
      stream: firestore.usersByRole(UserRole.student),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(message: 'Could not load student accounts: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final students = snapshot.data!;
        if (students.isEmpty) {
          return const AppEmptyState(
            icon: Icons.school_outlined,
            title: 'No student accounts yet',
            message: 'Students who sign up will be listed here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppSectionHeader(
              title: 'Students',
              subtitle: '${students.length} registered account${students.length == 1 ? '' : 's'}',
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < students.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.border),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                      leading: CircleAvatar(
                        backgroundColor: p.accent.withValues(alpha: 0.15),
                        child: Text(
                          students[i].name.isNotEmpty ? students[i].name[0].toUpperCase() : '?',
                          style: TextStyle(color: p.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        students[i].name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
                      ),
                      subtitle: Text(
                        students[i].email,
                        style: TextStyle(fontSize: 12, color: p.textSecondary),
                      ),
                      trailing: students[i].club == null
                          ? null
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                students[i].club!,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, color: p.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    );
  }
}

class _OrganizerCard extends StatefulWidget {
  final UserModel organizer;

  const _OrganizerCard({required this.organizer});

  @override
  State<_OrganizerCard> createState() => _OrganizerCardState();
}

class _OrganizerCardState extends State<_OrganizerCard> {
  bool _updating = false;

  Future<void> _setApproved(bool approved) async {
    if (!approved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Revoke approval?'),
          content: Text(
            '${widget.organizer.name} will no longer be able to publish new events. '
            'Events they already published stay live.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revoke')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _updating = true);
    try {
      await context.read<FirestoreService>().setOrganizerApproved(widget.organizer.uid, approved);
      if (!mounted) return;
      showAppSnack(
        context,
        approved
            ? '${widget.organizer.name} approved — they can publish events now.'
            : 'Approval revoked for ${widget.organizer.name}.',
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Could not update approval: $e', isError: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final o = widget.organizer;
    final approved = o.organizerApproved;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: (approved ? p.success : p.warning).withValues(alpha: 0.15),
                child: Icon(
                  approved ? Icons.verified : Icons.hourglass_top,
                  color: approved ? p.success : p.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: p.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(o.email, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ],
                ),
              ),
              AppTag(
                label: approved ? 'Approved' : 'Pending',
                color: approved ? p.success : p.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (o.club != null) _MetaChip(icon: Icons.account_balance_outlined, text: o.club!),
              if (o.staffId != null && o.staffId!.isNotEmpty)
                _MetaChip(icon: Icons.badge_outlined, text: 'Staff ID ${o.staffId}'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: _updating
                ? Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
                    ),
                  )
                : approved
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.danger,
                          side: BorderSide(color: p.danger.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Revoke approval'),
                        onPressed: () => _setApproved(false),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: p.success),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve organizer'),
                        onPressed: () => _setApproved(true),
                      ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: p.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
        ],
      ),
    );
  }
}
