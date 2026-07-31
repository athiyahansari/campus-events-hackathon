import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/interest_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Set<String>? _editedInterests;
  bool _saving = false;

  Future<void> _save() async {
    if (_editedInterests == null) return;
    setState(() => _saving = true);
    await context.read<AuthProvider>().updateInterests(_editedInterests!.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Interests updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile;
    final isStudent = profile != null && profile.role == UserRole.student;
    final currentInterests = _editedInterests ?? profile?.interests.toSet() ?? {};
    final hasChanges = profile != null &&
        _editedInterests != null &&
        !setEquals(_editedInterests, profile.interests.toSet());

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(profile?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
                Text(profile?.email ?? ''),
                Text(profile?.club ?? (isStudent ? 'Student' : '')),
              ],
            ),
          ),
          if (isStudent) ...[
            const SizedBox(height: 24),
            Text('Interests', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Used to personalize your feed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            InterestPicker(
              selected: currentInterests,
              onChanged: (next) => setState(() => _editedInterests = next),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: hasChanges && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Interests'),
            ),
          ],
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('Log Out'),
            ),
          ),
        ],
      ),
    );
  }
}
