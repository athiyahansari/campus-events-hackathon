import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile;
    final p = context.palette;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isStudent = profile.role == UserRole.student;

    return Scaffold(
      backgroundColor: p.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeader(profile: profile),
            const SizedBox(height: AppSpacing.lg),
            if (isStudent) ...[
              _StatsSection(userId: profile.uid),
              const SizedBox(height: AppSpacing.lg),
            ],
            _PersonalInfoSection(profile: profile),
            if (isStudent && profile.interests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _InterestsSection(interests: profile.interests),
            ],
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.danger,
                    side: BorderSide(color: p.danger.withValues(alpha: 0.4)),
                  ),
                  onPressed: () => context.read<AuthProvider>().signOut(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign out'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initials = profile.name.trim().isNotEmpty ? profile.name.trim()[0].toUpperCase() : '?';
    final roleText = switch (profile.role) {
      UserRole.organizer => 'Organizer',
      UserRole.admin => 'Super Admin',
      UserRole.student => 'Student',
    };

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppBrand.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Text(
                    'Profile',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) => IconButton(
                      icon: Icon(
                        themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: Colors.white70,
                      ),
                      tooltip: themeProvider.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
                      onPressed: themeProvider.toggleTheme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: AppBrand.accent, width: 2),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                profile.name,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                profile.email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _HeaderChip(icon: Icons.school, label: roleText, color: AppBrand.accent),
                  if (profile.club != null)
                    _HeaderChip(
                      icon: Icons.account_balance,
                      label: profile.club!,
                      color: const Color(0xFF5BD675),
                    ),
                  if (profile.isOrganizer)
                    _HeaderChip(
                      icon: profile.organizerApproved ? Icons.verified : Icons.hourglass_top,
                      label: profile.organizerApproved ? 'Approved' : 'Pending approval',
                      color: profile.organizerApproved
                          ? const Color(0xFF5BD675)
                          : const Color(0xFFFFB86B),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final String userId;

  const _StatsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<List<RegistrationModel>>(
      stream: firestore.userRegistrations(userId),
      builder: (context, snapshot) {
        final regs = snapshot.data ?? const <RegistrationModel>[];
        final registered = regs.length;
        final attended = regs.where((r) => r.checkedIn).length;
        final certificates = regs.where((r) => r.certificateRequested).length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Registered',
                  count: registered,
                  icon: Icons.local_activity_outlined,
                  iconColor: p.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  title: 'Attended',
                  count: attended,
                  icon: Icons.check_circle_outline,
                  iconColor: p.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  title: 'Certificates',
                  count: certificates,
                  icon: Icons.workspace_premium_outlined,
                  iconColor: p.warning,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: p.border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$count',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: p.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            title,
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

class _PersonalInfoSection extends StatelessWidget {
  final UserModel profile;

  const _PersonalInfoSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Personal information'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(icon: Icons.person_outline, label: 'Full name', value: profile.name),
                Divider(height: 1, color: p.border),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: profile.email),
                Divider(height: 1, color: p.border),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: profile.isOrganizer ? 'Staff ID' : 'Student ID',
                  value: profile.staffId?.isNotEmpty == true
                      ? profile.staffId!
                      : 'STU-${profile.uid.substring(0, 6).toUpperCase()}',
                ),
                Divider(height: 1, color: p.border),
                _InfoRow(
                  icon: Icons.account_balance_outlined,
                  label: 'Faculty / school',
                  value: profile.club ?? 'Not specified',
                ),
                if (!profile.isOrganizer) ...[
                  Divider(height: 1, color: p.border),
                  _InfoRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Academic year',
                    value: profile.batch?.isNotEmpty == true ? profile.batch! : 'Not specified',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestsSection extends StatelessWidget {
  final List<String> interests;

  const _InterestsSection({required this.interests});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Your interests',
            subtitle: 'Used to personalise your feed and prioritise released seats',
          ),
          AppCard(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: interests.map((i) => AppTag(label: i, color: p.info)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: p.textSecondary, size: 18),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
