import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../repositories/auth_repository.dart';
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
          const SnackBar(
            content: Text('Vui lòng đồng ý với điều khoản sử dụng để tiếp tục.'),
          ),
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
        dateOfBirth: _dateOfBirth.text.trim(),
        gender: _gender,
        address: _address.text.trim(),
      );
      if (!mounted) return;
      if (outcome.needsConfirmation) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ConfirmEmailScreen(email: _email.text.trim()),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text(
              'Đăng ký tài khoản thành công! Bạn có thể đăng nhập ngay.',
            ),
          ),
        );
        Navigator.of(context).pop(_email.text.trim());
      }
    } catch (e) {
      if (mounted) {
        final message = e is AuthRepositoryException
            ? e.message
            : 'Không thể đăng ký. Kiểm tra thông tin hoặc kết nối mạng.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(message),
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
                    'Đăng ký tài khoản Bệnh nhân',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thông tin sức khỏe của bạn được bảo mật tuyệt đối theo tiêu chuẩn y tế.',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.trim().length < 2
                        ? 'Vui lòng nhập họ và tên'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: emailValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Tạo mật khẩu',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => v == null || v.length < 6
                        ? 'Mật khẩu phải có ít nhất 6 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 16),
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
                      DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                      DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
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
                      labelText: 'Địa chỉ nơi ở',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập địa chỉ nơi ở'
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
                      'Tôi đồng ý với Điều khoản sử dụng và Chính sách bảo mật Y tế.',
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
                        : const Text('Hoàn tất Đăng ký'),
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
