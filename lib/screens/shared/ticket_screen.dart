import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';

class TicketScreen extends StatelessWidget {
  final EventModel event;
  final RegistrationModel registration;
  final bool justRegistered;

  const TicketScreen({
    super.key,
    required this.event,
    required this.registration,
    this.justRegistered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(justRegistered ? 'Registration Confirmed' : 'Your Ticket')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (justRegistered) ...[
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 48),
                const SizedBox(height: 8),
                Text(
                  "You're registered!",
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              Text(event.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(event.venue, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: registration.qrCodeData,
                  size: 240,
                  version: QrVersions.auto,
                ),
              ),
              const SizedBox(height: 24),
              if (registration.checkedIn)
                Chip(
                  label: const Text('Checked in'),
                  avatar: const Icon(Icons.check_circle, size: 18),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                )
              else
                const Text('Show this QR code at the door to check in.'),
              if (justRegistered) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
