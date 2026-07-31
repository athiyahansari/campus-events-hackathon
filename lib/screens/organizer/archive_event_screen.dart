import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

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
      showAppSnack(context, 'Please write a short summary of the event.', isError: true);
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
      // Pop both this screen and the manage screen behind it.
      Navigator.of(context)
        ..pop()
        ..pop();
      showAppSnack(context, 'Event archived and published to the public archive.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Could not archive event: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Archive Event')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: p.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: p.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: p.info),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Archiving moves "${widget.event.title}" into the public archive, where anyone '
                    'can read the recap. This cannot be undone from the app.',
                    style: TextStyle(fontSize: 12.5, color: p.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text(
            'Event recap',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: p.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _summaryController,
            decoration: const InputDecoration(
              hintText: 'How did it go? Highlights, turnout, winners…',
            ),
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text(
            'Photos (optional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: p.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Paste image URLs to show a gallery on the archive page.',
            style: TextStyle(fontSize: 12, color: p.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < _photoControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _photoControllers[i],
                      decoration: InputDecoration(hintText: 'Photo URL ${i + 1}'),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  if (_photoControllers.length > 1)
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: p.danger),
                      tooltip: 'Remove',
                      onPressed: () => setState(() {
                        _photoControllers.removeAt(i).dispose();
                      }),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add another photo'),
              onPressed: () => setState(() => _photoControllers.add(TextEditingController())),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.archive_outlined),
              label: Text(_submitting ? 'Archiving…' : 'Archive event'),
              onPressed: _submitting ? null : _submit,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
