import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_repository_provider.dart';
import 'forgot_password_screen.dart';
import 'role_home.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _isDoctorMode = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedAccount();
  }

  Future<void> _loadRememberedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool('auth_remember_me') ?? false;
    if (remembered && mounted) {
      final savedEmail = prefs.getString('auth_remembered_email') ?? '';
      final isDoc = prefs.getBool('auth_remembered_is_doctor') ?? false;
      setState(() {
        _rememberMe = true;
        _email.text = savedEmail;
        _isDoctorMode = isDoc;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await authRepository.signIn(
        _email.text.trim(),
        _password.text,
        demoName: _name.text.trim(),
      );
      if (user == null) throw StateError('No signed-in user');

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('auth_remember_me', true);
        await prefs.setString('auth_remembered_email', _email.text.trim());
        await prefs.setBool('auth_remembered_is_doctor', _isDoctorMode);
      } else {
        await prefs.setBool('auth_remember_me', false);
        await prefs.remove('auth_remembered_email');
        await prefs.remove('auth_remembered_is_doctor');
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => homeForRole(user.role, user: user)),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        final message = e is AuthRepositoryException
            ? e.message
            : 'Không thể đăng nhập. Kiểm tra email, mật khẩu hoặc kết nối mạng.';
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
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 42, 24, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: HospitalLogo()),
                  const SizedBox(height: 28),
                  Text(
                    _isDoctorMode ? 'Hệ thống Y tế Bác sĩ' : 'Smart Hospital',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isDoctorMode
                        ? 'Cổng Bác sĩ & Bệnh án Điện tử (EMR/HIS)'
                        : 'Đăng nhập để quản lý lịch khám và sức khỏe gia đình.',
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 20),
                  // Role Selector Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isDoctorMode = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isDoctorMode
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isDoctorMode
                                    ? [
                                        const BoxShadow(
                                          color: Color(0x14000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 18,
                                    color: !_isDoctorMode
                                        ? AppColors.primary
                                        : AppColors.mutedText,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Bệnh nhân',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: !_isDoctorMode
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: !_isDoctorMode
                                            ? AppColors.primary
                                            : AppColors.mutedText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isDoctorMode = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isDoctorMode
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isDoctorMode
                                    ? [
                                        const BoxShadow(
                                          color: Color(0x14000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    size: 18,
                                    color: _isDoctorMode
                                        ? const Color(0xFF0D9488)
                                        : AppColors.mutedText,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Bác sĩ / Y tế',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: _isDoctorMode
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _isDoctorMode
                                            ? const Color(0xFF0D9488)
                                            : AppColors.mutedText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isDoctorMode) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0D9488)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: Color(0xFF0D9488),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Khu vực EMR/HIS bảo mật: Dành riêng cho Bác sĩ & Cán bộ y tế được cấp tài khoản.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0D9488),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _isDoctorMode
                          ? 'Mã Bác sĩ / Email Bệnh viện'
                          : 'Email',
                      hintText: _isDoctorMode
                          ? 'doctor.linh@hospital.com'
                          : 'patient.an@hospital.com',
                      prefixIcon: Icon(
                        _isDoctorMode
                            ? Icons.badge_outlined
                            : Icons.mail_outline,
                      ),
                    ),
                    validator: emailValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: _isDoctorMode
                          ? 'Mật khẩu Bác sĩ'
                          : 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 6
                        ? 'Mật khẩu phải có ít nhất 6 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) =>
                                        setState(() => _rememberMe = val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text(
                                    'Ghi nhớ tài khoản',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isDoctorMode
                                ? 'Đăng nhập Bàn khám Bác sĩ'
                                : 'Đăng nhập',
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'BẠN CHƯA CÓ TÀI KHOẢN?',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final registeredEmail = await Navigator.of(context).push<String>(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                      if (registeredEmail != null && registeredEmail.isNotEmpty) {
                        setState(() {
                          _email.text = registeredEmail;
                          _isDoctorMode = false;
                        });
                      }
                    },
                    child: const Text('Đăng ký tài khoản Bệnh nhân'),
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

String? emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Vui lòng nhập địa chỉ email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
    return 'Địa chỉ email không đúng định dạng';
  }
  return null;
}
