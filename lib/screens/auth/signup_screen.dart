import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/clubs.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/interest_picker.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _batchController = TextEditingController();
  final _staffIdController = TextEditingController();

  UserRole _role = UserRole.student;
  String? _club;
  Set<String> _interests = {};
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _batchController.dispose();
    _staffIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
      club: _club,
      interests: _role == UserRole.student ? _interests.toList() : const [],
      age: _role == UserRole.student ? int.tryParse(_ageController.text.trim()) : null,
      batch: _role == UserRole.student ? _batchController.text.trim() : null,
      staffId: _role == UserRole.organizer ? _staffIdController.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      showAppSnack(
        context,
        _role == UserRole.organizer
            ? 'Account created. An admin must approve you before you can publish events.'
            : 'Account created — welcome!',
      );
    } else {
      showAppSnack(context, auth.errorMessage ?? 'Sign up failed.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isStudent = _role == UserRole.student;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                            value: UserRole.student, label: Text('Student'), icon: Icon(Icons.school)),
                        ButtonSegment(
                            value: UserRole.organizer, label: Text('Organizer'), icon: Icon(Icons.badge)),
                      ],
                      selected: {_role},
                      onSelectionChanged: (selection) => setState(() {
                        _role = selection.first;
                        // Club means different things per role, so reset it when
                        // switching to avoid carrying over a stale selection.
                        _club = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (_role == UserRole.organizer)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: p.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: p.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 18, color: p.warning),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'Organizer accounts need admin approval before you can publish events. '
                                'You can create drafts straight away.',
                                style: TextStyle(fontSize: 12, color: p.textPrimary, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),

                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FieldLabel('Full name'),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(hintText: 'Your name'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          _FieldLabel('Email'),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(hintText: 'you@university.edu'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your email';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          _FieldLabel('Password'),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'At least 6 characters',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: p.textSecondary,
                                ),
                                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          if (isStudent) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _FieldLabel('Age'),
                                      TextFormField(
                                        controller: _ageController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(hintText: '20'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _FieldLabel('Batch / year'),
                                      TextFormField(
                                        controller: _batchController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(hintText: '2026'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          _FieldLabel(isStudent ? 'School' : 'Club / school you organise for'),
                          DropdownButtonFormField<String>(
                            initialValue: _club,
                            isExpanded: true,
                            decoration: const InputDecoration(hintText: 'Select one'),
                            items: kClubs
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _club = v),
                            validator: (v) => v == null ? 'Please select one' : null,
                          ),

                          if (_role == UserRole.organizer) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _FieldLabel('Staff ID / access code'),
                            TextFormField(
                              controller: _staffIdController,
                              decoration: const InputDecoration(hintText: 'Shown to the admin reviewing you'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required for organizer access' : null,
                            ),
                          ],

                          if (isStudent) ...[
                            const SizedBox(height: AppSpacing.xl),
                            _FieldLabel('Interests (optional)'),
                            Text(
                              'We use these to personalise your feed and to pick who gets a released seat.',
                              style: TextStyle(fontSize: 12, color: p.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            InterestPicker(
                              selected: _interests,
                              onChanged: (next) => setState(() => _interests = next),
                            ),
                          ],
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
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create account'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: context.palette.textPrimary,
        ),
      ),
    );
  }
}
