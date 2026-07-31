import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';

class TicketScreen extends StatelessWidget {
  final EventModel event;
  final RegistrationModel registration;

  const TicketScreen({super.key, required this.event, required this.registration});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Ticket')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),
        ),
      ),
    );
  }
}
