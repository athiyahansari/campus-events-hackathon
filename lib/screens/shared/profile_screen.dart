import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(profile?.name ?? ''),
            Text(profile?.email ?? ''),
            Text(profile?.club ?? 'No club'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}
