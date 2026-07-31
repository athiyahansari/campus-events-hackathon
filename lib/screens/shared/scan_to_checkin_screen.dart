import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class ScanToCheckinScreen extends StatefulWidget {
  final EventModel event;

  const ScanToCheckinScreen({super.key, required this.event});

  @override
  State<ScanToCheckinScreen> createState() => _ScanToCheckinScreenState();
}

class _ScanToCheckinScreenState extends State<ScanToCheckinScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  bool _succeeded = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    // Ignore further frames once we're working or already done, otherwise the
    // scanner fires continuously and spams the transaction.
    if (_processing || _succeeded) return;
    final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (code == null) return;

    final userId = context.read<AuthProvider>().firebaseUser?.uid;
    if (userId == null) return;

    setState(() => _processing = true);
    try {
      await context.read<FirestoreService>().selfCheckIn(
            eventId: widget.event.id,
            userId: userId,
            scannedToken: code,
          );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _succeeded = true;
        _message = "You're checked in!";
        _isError = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _message = _friendlyMessage(e);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Turns exception objects into something a student can act on, instead of
  /// dumping a raw `Exception: ...` string on screen.
  String _friendlyMessage(Object e) {
    if (e is InvalidCheckinTokenException) {
      return 'That code has expired. Ask the organizer for the current one on screen.';
    }
    if (e is AlreadyCheckedInException) {
      return "You're already checked in for this event.";
    }
    if (e is NotRegisteredException) {
      return "You're not registered for this event, so you can't check in.";
    }
    return 'Check-in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),

          // Viewfinder
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _succeeded ? p.success : Colors.white.withValues(alpha: 0.9),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            ),
          ),

          Positioned(
            top: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Point your camera at the check-in QR shown by the organizer.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),

          if (_message != null)
            Positioned(
              bottom: AppSpacing.xl,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: SafeArea(
                top: false,
                child: AnimatedSlide(
                  offset: Offset.zero,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: _isError ? p.danger : p.success,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isError ? Icons.error_outline : Icons.check_circle,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _message!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (_isError)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            tooltip: 'Dismiss',
                            onPressed: () => setState(() => _message = null),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
