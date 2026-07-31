import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';

class ScanScreen extends StatefulWidget {
  final EventModel event;

  const ScanScreen({super.key, required this.event});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _lastMessage;
  Color _lastColor = Colors.grey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() => _processing = true);
    try {
      await context.read<FirestoreService>().checkIn(
            qrCodeData: code,
            expectedEventId: widget.event.id,
          );
      _showResult('Checked in ✓', Colors.green);
    } catch (e) {
      _showResult(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showResult(String message, Color color) {
    if (!mounted) return;
    setState(() {
      _lastMessage = message;
      _lastColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan · ${widget.event.title}')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          if (_processing)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_lastMessage != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _lastMessage!,
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

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
