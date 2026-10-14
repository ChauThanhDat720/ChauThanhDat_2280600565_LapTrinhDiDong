import 'package:flutter/material.dart';

import '../repositories/auth_repository_provider.dart';
import 'login_screen.dart';

class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({super.key, required this.email});
  final String email;
  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  final code = TextEditingController();
  bool loading = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> confirm() async {
    if (code.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      await authRepository.confirmSignUp(widget.email, code.text.trim());
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã xác minh không hợp lệ hoặc đã hết hạn.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Xác minh tài khoản')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Nhập mã đã gửi đến ${widget.email}'),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Mã xác minh'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : confirm,
            child: const Text('Xác nhận'),
          ),
          TextButton(
            onPressed: () => authRepository.resendSignUpCode(widget.email),
            child: const Text('Gửi lại mã'),
          ),
        ],
      ),
    ),
  );
}
