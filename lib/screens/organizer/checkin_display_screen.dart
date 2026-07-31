import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';

class CheckinDisplayScreen extends StatefulWidget {
  final EventModel event;

  const CheckinDisplayScreen({super.key, required this.event});

  @override
  State<CheckinDisplayScreen> createState() => _CheckinDisplayScreenState();
}

class _CheckinDisplayScreenState extends State<CheckinDisplayScreen> {
  Timer? _rotationTimer;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    final firestore = context.read<FirestoreService>();
    firestore.startCheckinSession(widget.event.id);
    _rotationTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => firestore.startCheckinSession(widget.event.id),
    );
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    // Best-effort: invalidate the token even if the user leaves via the system back
    // gesture instead of the Stop Session button.
    context.read<FirestoreService>().stopCheckinSession(widget.event.id);
    super.dispose();
  }

  Future<void> _stopSession() async {
    setState(() => _stopping = true);
    _rotationTimer?.cancel();
    await context.read<FirestoreService>().stopCheckinSession(widget.event.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.event.title),
      ),
      body: StreamBuilder<EventModel?>(
        stream: firestore.watchEvent(widget.event.id),
        initialData: widget.event,
        builder: (context, snapshot) {
          final current = snapshot.data ?? widget.event;
          final token = current.activeCheckinToken;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${current.checkedInCount} checked in',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: token == null
                      ? const SizedBox(
                          width: 320,
                          height: 320,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : QrImageView(
                          data: token,
                          size: 320,
                          version: QrVersions.auto,
                        ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scan to check in · refreshes automatically',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 40),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(_stopping ? 'Stopping…' : 'Stop Session'),
                  onPressed: _stopping ? null : _stopSession,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
