import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/clubs.dart';
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
    if (_role == UserRole.organizer && _staffIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Staff ID to request organizer access.')),
      );
      return;
    }
    if (_role == UserRole.student && _club == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your school.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
      club: _role == UserRole.student ? _club : null,
      interests: _role == UserRole.student ? _interests.toList() : const [],
      age: _role == UserRole.student ? int.tryParse(_ageController.text.trim()) : null,
      batch: _role == UserRole.student ? _batchController.text.trim() : null,
      staffId: _role == UserRole.organizer ? _staffIdController.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Sign up failed.')),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscure = false, bool isPassword = false, TextInputType? keyboardType, String? Function(String?)? validator}) {
    final isObscured = isPassword ? _obscurePassword : obscure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: isObscured,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6E747F), // Dark grey-blue background overlay
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top section with Icon and Back Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7CC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.person_add, color: Colors.purple[300]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2F4D),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(value: UserRole.student, label: Text('Student'), icon: Icon(Icons.school)),
                      ButtonSegment(value: UserRole.organizer, label: Text('Organizer'), icon: Icon(Icons.badge)),
                    ],
                    selected: {_role},
                    onSelectionChanged: (selection) => setState(() => _role = selection.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: const Color(0xFF1E2F4D).withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildTextField('Full Name', _nameController, validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null),
                  const SizedBox(height: 16),
                  _buildTextField('Email', _emailController, keyboardType: TextInputType.emailAddress, validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  }),
                  const SizedBox(height: 16),
                  _buildTextField('Password', _passwordController, isPassword: true, validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null),
                  const SizedBox(height: 16),
                  
                  if (_role == UserRole.student) ...[
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Age', _ageController, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Batch (Year)', _batchController, keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('School / Club', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _club,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: kClubs.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _club = v),
                      validator: (v) => v == null ? 'Please select one' : null,
                    ),
                  ],

                  if (_role == UserRole.organizer) ...[
                    _buildTextField(
                      'Staff ID / Access Code', 
                      _staffIdController, 
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required for organizer access' : null
                    ),
                  ],
                  
                  if (_role == UserRole.student) ...[
                    const SizedBox(height: 24),
                    const Text('Interests (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    InterestPicker(
                      selected: _interests,
                      onChanged: (next) => setState(() => _interests = next),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2F4D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
