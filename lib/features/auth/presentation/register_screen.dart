import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../repositories/auth_repository_provider.dart';
import 'confirm_email_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _address = TextEditingController();
  String _gender = 'Không muốn nêu';
  bool _acceptedTerms = false;
  bool _loading = false;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _dateOfBirth.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || !_acceptedTerms) {
      if (!_acceptedTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please accept the terms to continue.')),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final outcome = await authRepository.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      if (outcome.needsConfirmation) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ConfirmEmailScreen(email: _email.text.trim()),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể đăng ký. Kiểm tra thông tin hoặc kết nối mạng.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create your account',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your medical information stays private and secure.',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.trim().length < 2
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: emailValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Create password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => v == null || v.length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 9
                        ? 'Nhập số điện thoại hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dateOfBirth,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Ngày sinh (dd/mm/yyyy)',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập ngày sinh'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Giới tính',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                      DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                      DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                      DropdownMenuItem(
                        value: 'Không muốn nêu',
                        child: Text('Không muốn nêu'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _gender = value ?? _gender),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _address,
                    textCapitalization: TextCapitalization.words,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập địa chỉ'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _acceptedTerms,
                    onChanged: (value) =>
                        setState(() => _acceptedTerms = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I agree to the Terms of Use and Privacy Policy',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
