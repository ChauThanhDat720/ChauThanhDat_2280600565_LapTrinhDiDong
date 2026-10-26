import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/session/patient_session.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/repositories/auth_repository_provider.dart';
import '../data/patient_repository.dart';
import '../domain/patient_profile.dart';
import '../../team/presentation/team_screen.dart';
import '../../tools/alarm/alarm_screen.dart';
import '../../tools/speech/speech_screen.dart';
import '../../tools/translation/translation_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.repository = const LocalPatientRepository(),
  });
  final PatientRepository repository;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  PatientProfile? _profile;
  Object? _error;
  bool _loading = true;
  bool get _isDemo => widget.repository is LocalPatientRepository;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.repository.getMyProfile();
      if (!mounted) return;
      setState(() => _profile = value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang tải hồ sơ bệnh nhân...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không thể tải hồ sơ bệnh nhân.'),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final p = _profile;
    if (p == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bạn chưa hoàn thiện hồ sơ bệnh nhân.'),
            ElevatedButton(
              onPressed: () => _edit(context),
              child: const Text('Hoàn thiện hồ sơ'),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Text(
                'Hồ sơ bệnh nhân',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              if (_isDemo) const Chip(label: Text('Chế độ demo')),
              IconButton(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CircleAvatar(radius: 40, child: const Icon(Icons.person, size: 42)),
          const SizedBox(height: 12),
          Text(
            p.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Mã bệnh nhân: ${p.patientId ?? 'Chưa cấp'}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _field('Email', p.email),
          _field('Số điện thoại', p.phone),
          _field('Ngày sinh', p.dateOfBirth),
          _field('Giới tính', p.gender),
          _field('Địa chỉ', p.address),
          _field('Người liên hệ khẩn cấp', p.emergencyContactName),
          _field('Số điện thoại liên hệ khẩn cấp', p.emergencyContactPhone),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              side: const BorderSide(color: Color(0xFFFFD9D9)),
            ),
            onPressed: () async {
              await authRepository.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Widget _field(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      title: Text(title),
      subtitle: Text(value.isEmpty ? 'Chưa cập nhật' : value),
    ),
  );
  Future<void> _edit(BuildContext c) async {
    await Navigator.of(c).push(
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(repository: widget.repository, profile: _profile),
      ),
    );
    if (mounted) _load();
  }
}

// Legacy layout is retained during the Profile repository migration.
// ignore: unused_element
class _LegacyProfileScreen extends StatelessWidget {
  // ignore: unused_element_parameter
  const _LegacyProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: PatientSession.instance,
    builder: (context, _) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Hồ sơ bệnh nhân',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Color(0xFFD8F0F2),
                      child: Icon(
                        Icons.person,
                        size: 46,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      PatientSession.instance.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Mã bệnh nhân: Chế độ demo',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                    SizedBox(height: 16),
                    Chip(
                      label: Text('Patient'),
                      avatar: Icon(
                        Icons.verified_user_outlined,
                        size: 17,
                        color: AppColors.success,
                      ),
                      backgroundColor: Color(0xFFE5F6EF),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Personal information'),
              const SizedBox(height: 14),
              InfoTile(
                icon: Icons.mail_outline,
                title: 'Email',
                subtitle: PatientSession.instance.email,
              ),
              const SizedBox(height: 10),
              InfoTile(
                icon: Icons.phone_outlined,
                title: 'Phone',
                subtitle: PatientSession.instance.phone,
              ),
              const SizedBox(height: 10),
              InfoTile(
                icon: Icons.cake_outlined,
                title: 'Ngày sinh',
                subtitle: PatientSession.instance.dateOfBirth,
              ),
              const SizedBox(height: 10),
              InfoTile(
                icon: Icons.person_outline,
                title: 'Giới tính',
                subtitle: PatientSession.instance.gender,
              ),
              const SizedBox(height: 10),
              InfoTile(
                icon: Icons.location_on_outlined,
                title: 'Địa chỉ',
                subtitle: PatientSession.instance.address,
              ),
              const SizedBox(height: 10),
              InfoTile(
                icon: Icons.contact_emergency_outlined,
                title: 'Người liên hệ khẩn cấp',
                subtitle: PatientSession.instance.emergencyContactName.isEmpty
                    ? 'Chưa cập nhật'
                    : PatientSession.instance.emergencyContactName,
              ),
              const SizedBox(height: 10),
              InfoTile(
                icon: Icons.phone_in_talk_outlined,
                title: 'Số điện thoại liên hệ khẩn cấp',
                subtitle: PatientSession.instance.emergencyContactPhone.isEmpty
                    ? 'Chưa cập nhật'
                    : PatientSession.instance.emergencyContactPhone,
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Tiện ích'),
              const SizedBox(height: 14),
              _ProfileAction(
                icon: Icons.phone_outlined,
                title: 'Gọi Smart Hospital',
                subtitle: 'Hotline 1900 1234',
                onTap: () =>
                    _launch(context, Uri(scheme: 'tel', path: '19001234')),
              ),
              const SizedBox(height: 10),
              _ProfileAction(
                icon: Icons.play_circle_outline,
                title: 'Kênh YouTube',
                subtitle: 'Xem video hướng dẫn sức khỏe',
                onTap: () =>
                    _launch(context, Uri.parse('https://www.youtube.com')),
              ),
              const SizedBox(height: 10),
              _ProfileAction(
                icon: Icons.alarm_outlined,
                title: 'Báo thức giọng nói',
                subtitle: 'Đặt lời nhắc bằng tiếng Việt',
                onTap: () => _open(context, const AlarmScreen()),
              ),
              const SizedBox(height: 10),
              _ProfileAction(
                icon: Icons.record_voice_over_outlined,
                title: 'Speech to Text',
                subtitle: 'Chuyển giọng nói thành văn bản',
                onTap: () => _open(context, const SpeechScreen()),
              ),
              const SizedBox(height: 10),
              _ProfileAction(
                icon: Icons.translate,
                title: 'Dịch văn bản',
                subtitle: 'Google ML Kit Translate',
                onTap: () => _open(context, const TranslationScreen()),
              ),
              const SizedBox(height: 10),
              _ProfileAction(
                icon: Icons.groups_outlined,
                title: 'Thông tin nhóm',
                subtitle: 'Vuốt để xem từng thành viên',
                onTap: () => _open(context, const TeamScreen()),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Account'),
              const SizedBox(height: 14),
              const InfoTile(
                icon: Icons.lock_outline,
                title: 'Security',
                subtitle: 'Password and sign-in settings',
                trailing: Icon(Icons.chevron_right, color: AppColors.mutedText),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFFD9D9)),
                ),
                onPressed: () async {
                  await authRepository.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
Future<void> _launch(BuildContext context, Uri uri) async {
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không thể mở ứng dụng trên thiết bị này.')),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: InfoTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right, color: AppColors.mutedText),
    ),
  );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.repository = const LocalPatientRepository(),
    this.profile,
  });
  final PatientRepository repository;
  final PatientProfile? profile;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _dateOfBirth;
  late final TextEditingController _address;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;
  late final PatientRepository _repository = widget.repository;
  late String _gender;
  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(
      text: profile?.name ?? PatientSession.instance.name,
    );
    _email = TextEditingController(
      text: profile?.email ?? PatientSession.instance.email,
    );
    _phone = TextEditingController(
      text: profile?.phone ?? PatientSession.instance.phone,
    );
    _dateOfBirth = TextEditingController(
      text: profile?.dateOfBirth ?? PatientSession.instance.dateOfBirth,
    );
    _address = TextEditingController(
      text: profile?.address ?? PatientSession.instance.address,
    );
    _emergencyName = TextEditingController(
      text:
          profile?.emergencyContactName ??
          PatientSession.instance.emergencyContactName,
    );
    _emergencyPhone = TextEditingController(
      text:
          profile?.emergencyContactPhone ??
          PatientSession.instance.emergencyContactPhone,
    );
    _gender = PatientSession.instance.gender.isEmpty
        ? 'Không muốn nêu'
        : (profile?.gender ?? PatientSession.instance.gender);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _dateOfBirth.dispose();
    _address.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Email không hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Phone number is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dateOfBirth,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Ngày sinh (dd/mm/yyyy)',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ngày sinh là bắt buộc'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(labelText: 'Giới tính'),
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
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Địa chỉ là bắt buộc'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emergencyName,
                    decoration: const InputDecoration(
                      labelText: 'Người liên hệ khẩn cấp',
                    ),
                    validator: (v) => v != null && v.length > 120
                        ? 'Tên liên hệ quá dài'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emergencyPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại liên hệ khẩn cấp',
                    ),
                    validator: (v) =>
                        v != null && v.isNotEmpty && v.trim().length < 9
                        ? 'Số điện thoại không hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _repository.updateMyProfile(
                          PatientProfile(
                            name: _name.text,
                            email: _email.text,
                            phone: _phone.text,
                            dateOfBirth: _dateOfBirth.text,
                            gender: _gender,
                            address: _address.text,
                            emergencyContactName: _emergencyName.text,
                            emergencyContactPhone: _emergencyPhone.text,
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cập nhật thông tin thành công.'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Lưu thay đổi'),
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
