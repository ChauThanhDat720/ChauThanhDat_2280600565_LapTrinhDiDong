import '../../../core/config/aws_config.dart';

import 'package:flutter/material.dart';

import '../../../core/models/app_user.dart';
import '../../doctors/presentation/doctor_dashboard_screen.dart';
import '../../home/presentation/home_screen.dart';

Widget homeForRole(UserRole role, {AppUser? user}) => switch (role) {
  UserRole.patient => const PatientHomeScreen(),
  UserRole.doctor => DoctorDashboardScreen(
      doctorId: user?.doctorId ?? (AwsConfig.useAws ? (user?.id ?? '') : 'dr-linh'),
      doctorName: user?.fullName ?? 'BS. Trần Thảo Linh',
      department: user?.department ?? 'Khoa Tim mạch',
    ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Tài khoản chưa được phân quyền',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Liên hệ quản trị viên để được cấp quyền truy cập phù hợp.',
              textAlign: TextAlign.center,
            ),
          ],
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
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (_, i) => ListTile(
        leading: CircleAvatar(child: Text('${i + 1}')),
        title: Text(items[i]),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    ),
  );
}
