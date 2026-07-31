import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';

class ArchiveEventScreen extends StatefulWidget {
  final EventModel event;

  const ArchiveEventScreen({super.key, required this.event});

  @override
  State<ArchiveEventScreen> createState() => _ArchiveEventScreenState();
}

class _ArchiveEventScreenState extends State<ArchiveEventScreen> {
  final _summaryController = TextEditingController();
  final List<TextEditingController> _photoControllers = [TextEditingController()];
  bool _submitting = false;

  @override
  void dispose() {
    _summaryController.dispose();
    for (final c in _photoControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_summaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a short summary of the event.')),
      );
      return;
    }
    final photos = _photoControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

    setState(() => _submitting = true);
    try {
      await context.read<FirestoreService>().archiveEvent(
            widget.event.id,
            photos: photos,
            summary: _summaryController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context)
        ..pop()
        ..pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to archive: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archive Event')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Archiving moves "${widget.event.title}" into the public Historical Archive.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _summaryController,
            decoration: const InputDecoration(labelText: 'Event summary'),
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          Text('Photos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (int i = 0; i < _photoControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _photoControllers[i],
                      decoration: InputDecoration(labelText: 'Photo URL ${i + 1}'),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  if (_photoControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() => _photoControllers.removeAt(i)),
                    ),
                ],
              ),
            ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add another photo URL'),
            onPressed: () => setState(() => _photoControllers.add(TextEditingController())),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Archive Event'),
          ),
        ],
      ),
    );
  }
}
