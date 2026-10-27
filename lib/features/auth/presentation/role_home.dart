import '../../../core/config/aws_config.dart';

import 'package:flutter/material.dart';

import '../../../core/models/app_user.dart';
import '../../doctors/presentation/doctor_dashboard_screen.dart';
import '../../home/presentation/home_screen.dart';

Widget homeForRole(UserRole role, {AppUser? user}) => switch (role) {
  UserRole.patient => const PatientHomeScreen(),
  UserRole.doctor =>
    AwsConfig.useAws
        ? DoctorDashboardScreen(
            doctorId: user?.doctorId ?? user?.id ?? '',
            doctorName: user?.fullName ?? 'Bác sĩ',
            department: '',
          )
        : const DoctorHomeScreen(),
  UserRole.admin => const AdminDashboardScreen(),
  UserRole.unknown => const AccessDeniedScreen(),
};

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});
  @override
  Widget build(BuildContext c) => const DoctorDashboardScreen();
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext c) => const _PlaceholderHome(
    title: 'Quản trị Smart Hospital',
    items: [
      'Quản lý bác sĩ',
      'Quản lý khoa khám',
      'Quản lý bệnh nhân',
      'Quản lý lịch khám',
      'Quản lý tài khoản',
      'Thống kê hệ thống',
    ],
  );
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});
  @override
  Widget build(BuildContext c) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Không thể xác định quyền truy cập tài khoản.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome({required this.title, required this.items});
  final String title;
  final List<String> items;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Chức năng sẽ được mở khi backend xác thực quyền truy cập.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        ...items.map(
          (e) => Card(
            child: ListTile(
              title: Text(e),
              trailing: const Icon(Icons.lock_outline),
            ),
          ),
        ),
      ],
    ),
  );
}
