import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

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

    final organizerApproved = context.read<AuthProvider>().userProfile?.organizerApproved ?? false;
    final canPublish = organizerApproved || existing?.status == EventStatus.published;
    _publishImmediately = canPublish && (existing == null || existing.status == EventStatus.published);
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
      showAppSnack(context, 'Please set both a start and end time.', isError: true);
      return;
    }
    if (!_endTime!.isAfter(_startTime!)) {
      showAppSnack(context, 'End time must be after start time.', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final profile = auth.userProfile!;
    final firestore = context.read<FirestoreService>();
    final canPublish = profile.organizerApproved || widget.existingEvent?.status == EventStatus.published;
    final publishImmediately = _publishImmediately && canPublish;

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
          'bannerImageUrl':
              _bannerUrlController.text.trim().isEmpty ? null : _bannerUrlController.text.trim(),
          'status': eventStatusToString(publishImmediately ? EventStatus.published : EventStatus.draft),
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
          bannerImageUrl:
              _bannerUrlController.text.trim().isEmpty ? null : _bannerUrlController.text.trim(),
          organizerId: auth.firebaseUser!.uid,
          status: publishImmediately ? EventStatus.published : EventStatus.draft,
          archivePhotos: const [],
          archiveSummary: null,
          createdAt: DateTime.now(),
        );
        await firestore.createEvent(event);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(
        context,
        widget.isEditing
            ? 'Changes saved.'
            : publishImmediately
                ? 'Event published.'
                : 'Draft saved.',
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Could not save event: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = context.watch<AuthProvider>().userProfile;
    final category = widget.existingEvent?.category ?? profile?.club ?? '';
    final canPublish =
        (profile?.organizerApproved ?? false) || widget.existingEvent?.status == EventStatus.published;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Event' : 'Create Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Label('Event title'),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'e.g. Annual Tech Summit'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            _Label('Description'),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(hintText: 'What is this event about?'),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a description' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            _Label('Category'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: p.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      category.isEmpty ? 'No club assigned' : category,
                      style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Events are always categorised under your own club/school.',
              style: TextStyle(fontSize: 12, color: p.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),

            _Label('Venue'),
            TextFormField(
              controller: _venueController,
              decoration: const InputDecoration(hintText: 'e.g. Main Auditorium, Block A'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a venue' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            _Label('Capacity'),
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(hintText: 'Number of seats'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return 'Enter a positive number';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            _Label('Banner image URL (optional)'),
            TextFormField(
              controller: _bannerUrlController,
              decoration: const InputDecoration(hintText: 'Leave blank to auto-pick an image'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.xl),

            _Label('Schedule'),
            _DateTimeTile(
              label: 'Starts',
              value: _startTime,
              onTap: () async {
                final picked = await _pickDateTime(_startTime);
                if (picked != null) setState(() => _startTime = picked);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _DateTimeTile(
              label: 'Ends',
              value: _endTime,
              onTap: () async {
                final picked = await _pickDateTime(_endTime ?? _startTime);
                if (picked != null) setState(() => _endTime = picked);
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            _Label('Options'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    title: Text(
                      'Publish immediately',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
                    ),
                    subtitle: Text(
                      canPublish
                          ? 'Off saves it as a draft, visible only to you'
                          : 'Locked until an admin approves your organizer account',
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                    value: _publishImmediately,
                    onChanged: canPublish ? (v) => setState(() => _publishImmediately = v) : null,
                  ),
                  Divider(height: 1, color: p.border),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    title: Text(
                      'Participation certificates',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
                    ),
                    subtitle: Text(
                      'Checked-in attendees can request one after the event ends',
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                    value: _certificateEnabled,
                    onChanged: (v) => setState(() => _certificateEnabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        widget.isEditing
                            ? 'Save changes'
                            : (_publishImmediately ? 'Publish event' : 'Save draft'),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: context.palette.textPrimary,
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateTimeTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isSet = value != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: isSet ? p.border : p.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.event, size: 18, color: isSet ? p.accent : p.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 11, color: p.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      isSet ? DateFormat('EEE, MMM d, yyyy · h:mm a').format(value!) : 'Not set',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSet ? p.textPrimary : p.warning,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar_outlined, size: 18, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
