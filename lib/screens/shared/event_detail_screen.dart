import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/event_badge_chip.dart';
import '../auth/login_screen.dart';
import 'ticket_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _registering = false;

  Future<void> _register(String userId) async {
    setState(() => _registering = true);
    final firestore = context.read<FirestoreService>();
    try {
      final registration = await firestore.registerForEvent(eventId: widget.event.id, userId: userId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketScreen(event: widget.event, registration: registration, justRegistered: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final auth = context.watch<AuthProvider>();
    final firestore = context.read<FirestoreService>();
    final dateFormat = DateFormat('EEEE, MMM d, y · h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: ListView(
        children: [
          if (event.bannerImageUrl != null && event.bannerImageUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(imageUrl: event.bannerImageUrl!, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(event.category)),
                    EventBadgeChip(badge: event.badgeAt(DateTime.now())),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.calendar_today, text: dateFormat.format(event.startTime)),
                _InfoRow(icon: Icons.location_on, text: event.venue),
                _InfoRow(
                  icon: Icons.people,
                  text: event.isFull
                      ? 'Fully booked (${event.capacity} capacity)'
                      : '${event.capacity - event.registeredCount} of ${event.capacity} spots left',
                ),
                const SizedBox(height: 16),
                Text(event.description),
                const SizedBox(height: 24),
                _buildAction(context, event, auth, firestore),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    EventModel event,
    AuthProvider auth,
    FirestoreService firestore,
  ) {
    if (auth.status != AuthStatus.authenticated) {
      return FilledButton.icon(
        icon: const Icon(Icons.login),
        label: const Text('Log in to register'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      );
    }

    if (auth.isOrganizer) {
      return const SizedBox.shrink();
    }

    final userId = auth.firebaseUser!.uid;

    return StreamBuilder<RegistrationModel?>(
      stream: firestore.watchRegistration(eventId: event.id, userId: userId),
      builder: (context, snapshot) {
        final registration = snapshot.data;
        if (registration != null) {
          return FilledButton.icon(
            icon: const Icon(Icons.qr_code),
            label: const Text('View My QR Ticket'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TicketScreen(event: event, registration: registration),
              ),
            ),
          );
        }

        final disabled = _registering || event.isFull;
        return FilledButton(
          onPressed: disabled ? null : () => _register(userId),
          child: _registering
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(event.isFull ? 'Event Full' : 'Register'),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
