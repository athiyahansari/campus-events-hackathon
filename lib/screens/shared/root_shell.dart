import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../organizer/organizer_dashboard_screen.dart';
import '../student/my_tickets_screen.dart';
import 'archive_screen.dart';
import 'profile_screen.dart';
import 'public_feed_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAuthenticated = auth.status == AuthStatus.authenticated;
    final isOrganizer = auth.isOrganizer;

    final destinations = <_ShellTab>[
      _ShellTab('Feed', Icons.event, const PublicFeedScreen()),
      _ShellTab('Archive', Icons.history, const ArchiveScreen()),
      if (isAuthenticated && !isOrganizer)
        _ShellTab('My Tickets', Icons.qr_code, const MyTicketsScreen()),
      if (isAuthenticated && isOrganizer)
        _ShellTab('Dashboard', Icons.dashboard, const OrganizerDashboardScreen()),
      _ShellTab(
        isAuthenticated ? 'Profile' : 'Log In',
        isAuthenticated ? Icons.person : Icons.login,
        isAuthenticated ? const ProfileScreen() : const LoginScreen(),
      ),
    ];

    final safeIndex = _index < destinations.length ? _index : 0;

    return Scaffold(
      body: destinations[safeIndex].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations
            .map((d) => NavigationDestination(icon: Icon(d.icon), label: d.label))
            .toList(),
      ),
    );
  }
}

class _ShellTab {
  final String label;
  final IconData icon;
  final Widget screen;

  _ShellTab(this.label, this.icon, this.screen);
}
