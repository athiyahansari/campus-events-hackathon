import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/push_notification_service.dart';
import '../admin/admin_dashboard_screen.dart';
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

    if (!isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.isAdmin) {
      return const AdminDashboardScreen();
    }

    if (isOrganizer) {
      return DefaultTabController(
        length: 6,
        initialIndex: 5, // Start on Dashboard
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E2F4D),
            foregroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.event_note, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('UniEvents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange),
                padding: const EdgeInsets.all(8),
                child: const Text('O', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                child: const Text('Sign out', style: TextStyle(color: Colors.white70)),
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(icon: Icon(Icons.home, size: 20), text: 'Discover'),
                Tab(icon: Icon(Icons.calendar_month, size: 20), text: 'Calendar'),
                Tab(icon: Icon(Icons.map, size: 20), text: 'Map'),
                Tab(icon: Icon(Icons.history, size: 20), text: 'Archive'),
                Tab(icon: Icon(Icons.info, size: 20), text: 'About'),
                Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Dashboard'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              PublicFeedScreen(),
              Center(child: Text('Calendar - Coming Soon')),
              Center(child: Text('Map - Coming Soon')),
              ArchiveScreen(),
              Center(child: Text('About - Coming Soon')),
              OrganizerDashboardScreen(),
            ],
          ),
        ),
      );
    }

    // Student View (Bottom Navigation)
    final studentDestinations = <_ShellTab>[
      _ShellTab('Feed', Icons.calendar_today, const PublicFeedScreen()),
      _ShellTab('Archive', Icons.history, const ArchiveScreen()),
      _ShellTab('My Tickets', Icons.qr_code, const MyTicketsScreen()),
      _ShellTab('Profile', Icons.person, const ProfileScreen()),
    ];

    final safeIndex = _index < studentDestinations.length ? _index : 0;

    return Scaffold(
      body: studentDestinations[safeIndex].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: studentDestinations
            .map((d) => NavigationDestination(icon: Icon(d.icon), label: d.label))
            .toList(),
        backgroundColor: const Color(0xFFFAF9FB),
        indicatorColor: const Color(0xFFEFE8FC),
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
