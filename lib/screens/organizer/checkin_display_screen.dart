import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Full-screen projected QR for check-in. The token rotates every 45s so a
/// screenshot of the code stops working almost immediately.
class CheckinDisplayScreen extends StatefulWidget {
  final EventModel event;

  const CheckinDisplayScreen({super.key, required this.event});

  @override
  State<CheckinDisplayScreen> createState() => _CheckinDisplayScreenState();
}

class _CheckinDisplayScreenState extends State<CheckinDisplayScreen> {
  static const _rotationSeconds = 45;

  Timer? _rotationTimer;
  Timer? _countdownTimer;
  bool _stopping = false;
  int _secondsLeft = _rotationSeconds;

  @override
  void initState() {
    super.initState();
    // Keep the projector/laptop awake while the session is running.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final firestore = context.read<FirestoreService>();
    firestore.startCheckinSession(widget.event.id);

    _rotationTimer = Timer.periodic(const Duration(seconds: _rotationSeconds), (_) {
      firestore.startCheckinSession(widget.event.id);
      if (mounted) setState(() => _secondsLeft = _rotationSeconds);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : _rotationSeconds);
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Best-effort: invalidate the token even if the organizer leaves via the
    // system back gesture rather than the Stop button.
    context.read<FirestoreService>().stopCheckinSession(widget.event.id);
    super.dispose();
  }

  Future<void> _stopSession() async {
    setState(() => _stopping = true);
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();
    await context.read<FirestoreService>().stopCheckinSession(widget.event.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AppBrand.navy,
      appBar: AppBar(
        backgroundColor: AppBrand.navy,
        foregroundColor: Colors.white,
        title: Text(widget.event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: StreamBuilder<EventModel?>(
        stream: firestore.watchEvent(widget.event.id),
        initialData: widget.event,
        builder: (context, snapshot) {
          final current = snapshot.data ?? widget.event;
          final token = current.activeCheckinToken;

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Scale the QR to the screen so it projects large but never overflows.
                final qrSize = (constraints.biggest.shortestSide * 0.62).clamp(180.0, 380.0);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CounterPill(
                            value: '${current.checkedInCount}',
                            label: 'Checked in',
                            color: const Color(0xFF5BD675),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _CounterPill(
                            value: '${current.registeredCount}',
                            label: 'Registered',
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: token == null
                            ? SizedBox(
                                width: qrSize,
                                height: qrSize,
                                child: const Center(child: CircularProgressIndicator()),
                              )
                            : QrImageView(
                                data: token,
                                size: qrSize,
                                version: QrVersions.auto,
                                // QrImageView draws dark-on-white; force it so it
                                // stays scannable regardless of app theme.
                                backgroundColor: Colors.white,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: _secondsLeft / _rotationSeconds,
                              strokeWidth: 2,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Code refreshes in ${_secondsLeft}s',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                        child: Text(
                          'Students scan this from their ticket to check in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(_stopping ? 'Stopping…' : 'Stop session'),
                        onPressed: _stopping ? null : _stopSession,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _CounterPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
