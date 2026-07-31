import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile;
    final isStudent = profile?.role == UserRole.student;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeader(profile: profile),
            if (isStudent) const SizedBox(height: 16),
            if (isStudent) _StatsSection(userId: profile.uid),
            const SizedBox(height: 24),
            _PersonalInfoSection(profile: profile),
            const SizedBox(height: 32),
            Center(
              child: TextButton.icon(
                onPressed: () => context.read<AuthProvider>().signOut(),
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
            const SizedBox(height: 32),
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
    final initials = profile.name.isNotEmpty ? profile.name.substring(0, 1).toUpperCase() : '?';
    final roleText = profile.isOrganizer ? 'Organizer' : 'Undergraduate Student';
    final idText = profile.isOrganizer
        ? (profile.staffId ?? 'No ID')
        : (profile.staffId ?? 'ID: ${profile.uid.substring(0, 8).toUpperCase()}');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2F4D),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24),
              const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) => IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white70,
                  ),
                  tooltip: 'Toggle Theme',
                  onPressed: () => themeProvider.toggleTheme(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent, width: 2),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.blueAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(roleText, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge, color: Colors.greenAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(idText, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (profile.isOrganizer) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (profile.organizerApproved ? Colors.greenAccent : Colors.orangeAccent).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    profile.organizerApproved ? Icons.verified : Icons.hourglass_top,
                    color: profile.organizerApproved ? Colors.greenAccent : Colors.orangeAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profile.organizerApproved ? 'Approved organizer' : 'Pending admin approval',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
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

class _StatsSection extends StatelessWidget {
  final String userId;

  const _StatsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<List<RegistrationModel>>(
      stream: firestore.userRegistrations(userId),
      builder: (context, snapshot) {
        final regs = snapshot.data ?? [];
        final registered = regs.length;
        final attended = regs.where((r) => r.checkedIn).length;
        final upcoming = registered - attended; // Rough proxy for upcoming

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _StatCard(title: 'Registered', count: registered, icon: Icons.local_activity, iconColor: Colors.blueAccent)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(title: 'Attended', count: attended, icon: Icons.check_circle_outline, iconColor: Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(title: 'Upcoming', count: upcoming, icon: Icons.calendar_today, iconColor: Colors.orange)),
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

  const _StatCard({required this.title, required this.count, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.contact_mail, color: Color(0xFF1E2F4D)),
              SizedBox(width: 8),
              Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                _InfoRow(icon: Icons.person_outline, label: 'Full Name', value: profile.name),
                const Divider(height: 1, color: Colors.black12),
                _InfoRow(icon: Icons.email_outlined, label: 'University Email', value: profile.email),
                const Divider(height: 1, color: Colors.black12),
                _InfoRow(
                    icon: Icons.badge_outlined,
                    label: profile.isOrganizer ? 'Staff ID' : 'Student ID',
                    value: profile.staffId ?? 'STU-${profile.uid.substring(0, 8).toUpperCase()}'),
                const Divider(height: 1, color: Colors.black12),
                _InfoRow(icon: Icons.account_balance_outlined, label: 'Faculty / School', value: profile.club ?? 'Not specified'),
                if (!profile.isOrganizer) ...[
                  const Divider(height: 1, color: Colors.black12),
                  _InfoRow(icon: Icons.calendar_month_outlined, label: 'Academic Year', value: profile.batch ?? 'Not specified'),
                ],
              ],
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.black54, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
