import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class CreateEventScreen extends StatefulWidget {
  final EventModel? existingEvent;

  const CreateEventScreen({super.key, this.existingEvent});

  bool get isEditing => existingEvent != null;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _venueController;
  late final TextEditingController _capacityController;
  late final TextEditingController _bannerUrlController;

  DateTime? _startTime;
  DateTime? _endTime;
  bool _publishImmediately = true;
  bool _certificateEnabled = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEvent;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _venueController = TextEditingController(text: existing?.venue ?? '');
    _capacityController = TextEditingController(text: existing != null ? '${existing.capacity}' : '');
    _bannerUrlController = TextEditingController(text: existing?.bannerImageUrl ?? '');
    _startTime = existing?.startTime;
    _endTime = existing?.endTime;
    _publishImmediately = existing == null || existing.status == EventStatus.published;
    _certificateEnabled = existing?.certificateEnabled ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _capacityController.dispose();
    _bannerUrlController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both a start and end time.')),
      );
      return;
    }
    if (!_endTime!.isAfter(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final profile = auth.userProfile!;
    final firestore = context.read<FirestoreService>();

    setState(() => _submitting = true);
    try {
      if (widget.isEditing) {
        await firestore.updateEvent(widget.existingEvent!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'venue': _venueController.text.trim(),
          'startTime': Timestamp.fromDate(_startTime!),
          'endTime': Timestamp.fromDate(_endTime!),
          'capacity': int.parse(_capacityController.text.trim()),
          'bannerImageUrl': _bannerUrlController.text.trim().isEmpty ? null : _bannerUrlController.text.trim(),
          'status': eventStatusToString(_publishImmediately ? EventStatus.published : EventStatus.draft),
          'certificateEnabled': _certificateEnabled,
        });
      } else {
        final event = EventModel(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: profile.club!,
          venue: _venueController.text.trim(),
          startTime: _startTime!,
          endTime: _endTime!,
          capacity: int.parse(_capacityController.text.trim()),
          registeredCount: 0,
          checkedInCount: 0,
          certificateEnabled: _certificateEnabled,
          bannerImageUrl: _bannerUrlController.text.trim().isEmpty ? null : _bannerUrlController.text.trim(),
          organizerId: auth.firebaseUser!.uid,
          status: _publishImmediately ? EventStatus.published : EventStatus.draft,
          archivePhotos: const [],
          archiveSummary: null,
          createdAt: DateTime.now(),
        );
        await firestore.createEvent(event);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save event: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Not set';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.existingEvent?.category ?? context.watch<AuthProvider>().userProfile?.club ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Event' : 'Create Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a description' : null,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Category'),
              child: Text(category),
            ),
            const SizedBox(height: 4),
            Text(
              'Events are always categorized under your own club/school.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venueController,
              decoration: const InputDecoration(labelText: 'Venue'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a venue' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(labelText: 'Capacity'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a positive number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bannerUrlController,
              decoration: const InputDecoration(labelText: 'Banner image URL (optional)'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start time'),
              subtitle: Text(_formatDateTime(_startTime)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await _pickDateTime(_startTime);
                if (picked != null) setState(() => _startTime = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End time'),
              subtitle: Text(_formatDateTime(_endTime)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await _pickDateTime(_endTime ?? _startTime);
                if (picked != null) setState(() => _endTime = picked);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publish immediately'),
              subtitle: const Text('Off = save as draft, visible only to you'),
              value: _publishImmediately,
              onChanged: (v) => setState(() => _publishImmediately = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable participation certificates'),
              subtitle: const Text('Checked-in attendees can request one once the event ends'),
              value: _certificateEnabled,
              onChanged: (v) => setState(() => _certificateEnabled = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.isEditing ? 'Save Changes' : (_publishImmediately ? 'Publish Event' : 'Save Draft')),
            ),
          ],
        ),
      ),
    );
  }
}
