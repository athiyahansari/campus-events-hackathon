import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class ScanToCheckinScreen extends StatefulWidget {
  final EventModel event;

  const ScanToCheckinScreen({super.key, required this.event});

  @override
  State<ScanToCheckinScreen> createState() => _ScanToCheckinScreenState();
}

class _ScanToCheckinScreenState extends State<ScanToCheckinScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _message;
  Color _messageColor = Colors.grey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) return;
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
      _showResult("You're checked in!", Colors.green, autoClose: true);
    } catch (e) {
      _showResult(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showResult(String message, Color color, {bool autoClose = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageColor = color;
    });
    if (autoClose) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan · ${widget.event.title}')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Point your camera at the check-in QR code shown by the organizer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          if (_processing)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_message != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _messageColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
