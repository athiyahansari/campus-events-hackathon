import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

/// The global super admin's home screen: review signed-up accounts, mainly to approve or
/// revoke organizers. An organizer can create events and save drafts as soon as they sign up,
/// but can't publish until approved here (enforced in firestore.rules, not just this UI).
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            child: const Text('Sign out', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Organizer Approvals', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'New organizer accounts can create events and save drafts immediately, but can only '
            'publish once approved here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<UserModel>>(
            stream: firestore.usersByRole(UserRole.organizer),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final organizers = snapshot.data!;
              if (organizers.isEmpty) {
                return const Text('No organizer accounts yet.');
              }
              // Pending review first.
              final sorted = [...organizers]..sort((a, b) {
                  if (a.organizerApproved == b.organizerApproved) return a.name.compareTo(b.name);
                  return a.organizerApproved ? 1 : -1;
                });
              return Column(
                children: sorted.map((organizer) => _OrganizerTile(organizer: organizer)).toList(),
              );
            },
          ),
          const Divider(height: 40),
          Text('Students', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Read-only — for reference.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          StreamBuilder<List<UserModel>>(
            stream: firestore.usersByRole(UserRole.student),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final students = snapshot.data!;
              if (students.isEmpty) {
                return const Text('No student accounts yet.');
              }
              return Column(
                children: students.map((student) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.school_outlined),
                    title: Text(student.name),
                    subtitle: Text(student.email),
                    trailing: Text(student.club ?? ''),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrganizerTile extends StatefulWidget {
  final UserModel organizer;

  const _OrganizerTile({required this.organizer});

  @override
  State<_OrganizerTile> createState() => _OrganizerTileState();
}

class _OrganizerTileState extends State<_OrganizerTile> {
  bool _updating = false;

  Future<void> _setApproved(bool approved) async {
    setState(() => _updating = true);
    try {
      await context.read<FirestoreService>().setOrganizerApproved(widget.organizer.uid, approved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizer = widget.organizer;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        organizer.organizerApproved ? Icons.verified : Icons.hourglass_top,
        color: organizer.organizerApproved ? Colors.green : Colors.orange,
      ),
      title: Text(organizer.name),
      subtitle: Text(
        '${organizer.email}'
        '${organizer.club != null ? ' · ${organizer.club}' : ''}'
        '${organizer.staffId != null && organizer.staffId!.isNotEmpty ? ' · Staff ID: ${organizer.staffId}' : ''}',
      ),
      trailing: _updating
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : organizer.organizerApproved
              ? OutlinedButton(
                  onPressed: () => _setApproved(false),
                  child: const Text('Revoke'),
                )
              : FilledButton(
                  onPressed: () => _setApproved(true),
                  child: const Text('Approve'),
                ),
      isThreeLine: false,
    );
  }
}
