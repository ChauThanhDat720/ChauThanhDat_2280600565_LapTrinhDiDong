import 'package:flutter/material.dart';

import '../repositories/auth_repository_provider.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController();
  bool sent = false, loading = false;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run() async {
    if (emailValidator(email.text) != null) return;
    setState(() => loading = true);
    try {
      if (!sent) {
        await authRepository.startPasswordReset(email.text.trim());
        setState(() => sent = true);
      } else {
        await authRepository.confirmPasswordReset(
          email.text.trim(),
          code.text.trim(),
          password.text,
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể thực hiện yêu cầu. Dịch vụ trực tuyến có thể chưa cấu hình.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Quên mật khẩu')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextFormField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          if (sent) ...[
            TextFormField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Mã xác minh'),
            ),
            TextFormField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : run,
            child: Text(sent ? 'Đặt lại mật khẩu' : 'Gửi mã xác minh'),
          ),
        ],
      ),
    ),
  );
}
