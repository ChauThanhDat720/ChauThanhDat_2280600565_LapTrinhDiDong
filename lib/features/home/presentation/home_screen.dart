import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/session/patient_session.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../appointments/presentation/appointment_list_screen.dart';
import '../../departments/presentation/department_screen.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../../location/presentation/patient_location_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../tools/ocr/ocr_screen.dart';
import '../../tools/presentation/tools_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});
  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const AppointmentListScreen(showAppBar: false),
      const ToolsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch khám',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Công cụ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();
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
                  const CircleAvatar(
                    radius: 23,
                    backgroundColor: Color(0xFFD8F0F2),
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning,',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                        Text(
                          PatientSession.instance.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _message(context, 'No new notifications.'),
                    icon: const Badge(
                      child: Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.navy],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your health, at a glance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Book an appointment or find the right specialist for your needs.',
                      style: TextStyle(color: Color(0xFFD5F4F5), height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DepartmentScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.local_hospital_outlined),
                      label: const Text('Tìm chuyên khoa'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const SectionTitle(title: 'Quick actions'),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.22,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Action(
                    icon: Icons.local_hospital_outlined,
                    title: 'Chuyên khoa',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DepartmentScreen(),
                      ),
                    ),
                  ),
                  _Action(
                    icon: Icons.medical_services_outlined,
                    title: 'Bác sĩ',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DoctorListScreen(),
                      ),
                    ),
                  ),
                  _Action(
                    icon: Icons.document_scanner_outlined,
                    title: 'Quét & dịch',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OcrScreen()),
                    ),
                  ),
                  _Action(
                    icon: Icons.location_on_rounded,
                    title: 'Vị trí của tôi',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PatientLocationScreen(),
                      ),
                    ),
                  ),
                  _Action(
                    icon: Icons.support_agent_outlined,
                    title: 'Get support',
                    onTap: () =>
                        _message(context, 'Our care team is here to help.'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionTitle(
                title: 'Upcoming appointment',
                action: Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const InfoTile(
                icon: Icons.calendar_today_outlined,
                title: 'No upcoming appointments',
                subtitle: 'Book a consultation with one of our specialists.',
                trailing: Icon(Icons.chevron_right, color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _message(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Ink(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 27),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
