import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/push_notification_service.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../organizer/organizer_dashboard_screen.dart';
import '../student/my_tickets_screen.dart';
import 'archive_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'public_feed_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  bool _pushInitStarted = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAuthenticated = auth.status == AuthStatus.authenticated;
    final isOrganizer = auth.isOrganizer;

    if (isAuthenticated && !isOrganizer && !_pushInitStarted && auth.userProfile != null) {
      _pushInitStarted = true;
      final userId = auth.userProfile!.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PushNotificationService>().initForUser(userId);
        context.read<FirestoreService>().recordAppOpen(userId);
      });
    }

    if (isAuthenticated && auth.isAdmin) {
      return const AdminDashboardScreen();
    }

    if (isAuthenticated && isOrganizer) {
      return const _OrganizerShell();
    }

    // Students AND signed-out guests share the same browsing shell — guests can
    // read the feed and archive, and hit a "Log In" tab instead of My Tickets /
    // Profile. Gating the whole app behind login previously made it impossible
    // to browse events without an account.
    final destinations = <_ShellTab>[
      _ShellTab('Feed', Icons.home_outlined, Icons.home, const PublicFeedScreen()),
      _ShellTab('Calendar', Icons.calendar_month_outlined, Icons.calendar_month, const CalendarScreen()),
      _ShellTab('Archive', Icons.history_outlined, Icons.history, const ArchiveScreen()),
      if (isAuthenticated)
        _ShellTab('My Tickets', Icons.confirmation_number_outlined, Icons.confirmation_number, const MyTicketsScreen()),
      if (isAuthenticated)
        _ShellTab('Profile', Icons.person_outline, Icons.person, const ProfileScreen())
      else
        _ShellTab('Log In', Icons.login_outlined, Icons.login, const LoginScreen()),
    ];

    final safeIndex = _index < destinations.length ? _index : 0;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: destinations.map((d) => d.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

/// Organizer chrome. The Calendar tab gives organizers a visual schedule of all events.
class _OrganizerShell extends StatelessWidget {
  const _OrganizerShell();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = context.watch<AuthProvider>().userProfile;
    final initial = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()[0].toUpperCase()
        : 'O';

    return DefaultTabController(
      length: 4,
      initialIndex: 3, // Land on Dashboard — an organizer's home base.
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.event_note, color: p.accent),
              const SizedBox(width: AppSpacing.sm),
              const Text('UniEvents'),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent),
              child: Text(
                initial,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
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
              Tab(icon: Icon(Icons.home_outlined, size: 20), text: 'Discover'),
              Tab(icon: Icon(Icons.calendar_month_outlined, size: 20), text: 'Calendar'),
              Tab(icon: Icon(Icons.history, size: 20), text: 'Archive'),
              Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Dashboard'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PublicFeedScreen(embedded: true),
            CalendarScreen(embedded: true),
            ArchiveScreen(embedded: true),
            OrganizerDashboardScreen(),
          ],
        ),
      ),
    );
  }
}

class _ShellTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  _ShellTab(this.label, this.icon, this.selectedIcon, this.screen);
}
