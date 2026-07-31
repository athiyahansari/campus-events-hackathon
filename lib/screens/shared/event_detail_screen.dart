import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../models/waitlist_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import 'scan_to_checkin_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _registering = false;
  bool _requestingCertificate = false;

  Future<void> _requestCertificate(String userId) async {
    setState(() => _requestingCertificate = true);
    final firestore = context.read<FirestoreService>();
    try {
      await firestore.requestCertificate(eventId: widget.event.id, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificate requested! The organizer will follow up.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _requestingCertificate = false);
    }
  }

  Future<void> _register(String userId) async {
    setState(() => _registering = true);
    final firestore = context.read<FirestoreService>();
    try {
      final outcome = await firestore.registerForEvent(eventId: widget.event.id, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome == RegistrationOutcome.registered
                ? "You're registered! We'll see you there."
                : "This event is full — you've been added to the waitlist. We'll notify you if a seat opens up.",
          ),
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
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');
    
    final isLive = event.status == EventStatus.published &&
        event.startTime.isBefore(DateTime.now().add(const Duration(hours: 1))) &&
        event.endTime.isAfter(DateTime.now());
        
    final progress = event.capacity > 0 ? (event.registeredCount / event.capacity).clamp(0.0, 1.0) : 0.0;
    final spotsLeft = event.capacity - event.registeredCount;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: (event.bannerImageUrl != null && event.bannerImageUrl!.isNotEmpty) 
                        ? event.bannerImageUrl! 
                        : 'https://via.placeholder.com/400x300',
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF1E2F4D),
                      child: const Center(
                        child: Icon(Icons.event, size: 64, color: Colors.white54),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent, Colors.black87],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  if (isLive)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Live Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(event.category, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D)),
                  ),
                  const SizedBox(height: 16),
                  
                  // Location and Date
                  _InfoRow(icon: Icons.location_on, iconColor: Colors.pinkAccent, text: event.venue),
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.calendar_month, iconColor: Colors.blueAccent, text: dateFormat.format(event.startTime)),
                  const SizedBox(height: 24),
                  
                  // Capacity Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(event.isFull ? Colors.red : Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.isFull ? 'Fully Booked' : '$spotsLeft spots left',
                        style: TextStyle(
                          fontSize: 14,
                          color: event.isFull ? Colors.red : Colors.black87,
                          fontWeight: event.isFull ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Row(
                        children: [
                          // Fake avatars for visual effect
                          ...List.generate(3, (index) => Align(
                            widthFactor: 0.6,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundImage: CachedNetworkImageProvider('https://i.pravatar.cc/100?img=${index + 1}'),
                              ),
                            ),
                          )),
                          const SizedBox(width: 8),
                          Text(
                            '+${event.registeredCount} going',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('About Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D))),
                  const SizedBox(height: 12),
                  Text(
                    event.description,
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                  ),
                  
                  if (event.status == EventStatus.archived) ...[
                    const SizedBox(height: 32),
                    const Text('Archive Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2F4D))),
                    const SizedBox(height: 12),
                    if (event.archiveSummary != null && event.archiveSummary!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          event.archiveSummary!,
                          style: const TextStyle(fontSize: 14, color: Colors.green, height: 1.5),
                        ),
                      ),
                    if (event.archivePhotos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: event.archivePhotos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: event.archivePhotos[i],
                              width: 160,
                              height: 120,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                width: 160,
                                height: 120,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_not_supported),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  
                  const SizedBox(height: 100), // Space for bottom action bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildAction(context, event, auth, firestore),
    );
  }

  Widget _buildAction(
    BuildContext context,
    EventModel event,
    AuthProvider auth,
    FirestoreService firestore,
  ) {
    if (auth.status != AuthStatus.authenticated) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3366FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Log in to register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
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
        
        Widget actionButton;
        
        if (registration != null) {
          if (registration.checkedIn) {
            if (!event.certificateEnabled || DateTime.now().isBefore(event.endTime)) {
              actionButton = const _StatusButton(text: 'Checked in', color: Colors.green, icon: Icons.check_circle);
            } else if (registration.certificateRequested) {
              actionButton = const _StatusButton(text: 'Certificate requested', color: Colors.orange, icon: Icons.workspace_premium);
            } else {
              actionButton = SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  icon: _requestingCertificate 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.workspace_premium),
                  label: const Text('Request Certificate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _requestingCertificate ? null : () => _requestCertificate(userId),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              );
            }
          } else {
            actionButton = SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan to Check In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ScanToCheckinScreen(event: event)),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3366FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            );
          }
        } else {
          actionButton = StreamBuilder<WaitlistModel?>(
            stream: firestore.watchWaitlistEntry(eventId: event.id, userId: userId),
            builder: (context, waitlistSnapshot) {
              if (waitlistSnapshot.data != null) {
                return const _StatusButton(text: "You're on the waitlist", color: Colors.orange, icon: Icons.hourglass_top);
              }

              final disabled = _registering;
              return SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: disabled ? null : () => _register(userId),
                  style: FilledButton.styleFrom(
                    backgroundColor: event.isFull ? Colors.orange : const Color(0xFF3366FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _registering
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(event.isFull ? 'Join Waitlist' : 'Register Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: actionButton,
        );
      },
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  
  const _StatusButton({required this.text, required this.color, required this.icon});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoRow({required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
