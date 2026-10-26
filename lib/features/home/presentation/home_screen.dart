import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/session/patient_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/presentation/appointment_list_screen.dart';
import '../../departments/presentation/department_screen.dart';
import '../../doctors/domain/doctor.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../../medical_records/presentation/lab_results_detail_screen.dart';
import '../../location/presentation/patient_location_screen.dart';
import '../../notifications/data/notification_store.dart';
import '../../notifications/presentation/notification_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../tools/ocr/ocr_screen.dart';
import '../../tools/presentation/tools_screen.dart';
import '../../medical_records/presentation/medical_records_screen.dart';
import '../../medicines/presentation/medicine_list_screen.dart';
import '../../appointments/presentation/digital_boarding_pass_screen.dart';
import '../../appointments/presentation/reception_checkin_screen.dart';
import '../../reminders/presentation/medication_reminder_screen.dart';
import '../../vitals/presentation/health_vitals_screen.dart';
import '../../payments/presentation/invoice_management_screen.dart';
import '../../family/presentation/family_selector_bar.dart';
import '../../family/presentation/family_members_screen.dart';
import '../../teleconsultation/presentation/post_care_chat_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({
    super.key,
    this.appointmentRepository = const LocalAppointmentRepository(),
  });

  final AppointmentRepository appointmentRepository;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        repository: widget.appointmentRepository,
        onViewAllAppointments: () => setState(() => _index = 1),
      ),
      AppointmentListScreen(
        showAppBar: false,
        repository: widget.appointmentRepository,
      ),
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

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.repository,
    required this.onViewAllAppointments,
  });

  final AppointmentRepository repository;
  final VoidCallback onViewAllAppointments;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Appointment? _upcomingAppointment;
  Appointment? _pendingFollowUp;
  Appointment? _latestCompletedAppointment;
  bool _loadingAppointment = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingAppointment();
  }

  Future<void> _loadUpcomingAppointment() async {
    try {
      final list = await widget.repository.getAppointments();
      final active = list.where((item) =>
          item.status == AppointmentStatus.pending ||
          item.status == AppointmentStatus.confirmed ||
          item.status == AppointmentStatus.checkedIn).toList();

      active.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.time.compareTo(b.time);
      });

      // Find pending follow-up (completed with followUpDate that has not been re-booked yet)
      Appointment? followUp;
      final completedWithFollowUp = list.where((item) =>
          item.status == AppointmentStatus.completed &&
          item.followUpDate != null).toList();

      completedWithFollowUp.sort((a, b) => b.date.compareTo(a.date));

      for (final comp in completedWithFollowUp) {
        final alreadyBooked = list.any((other) =>
            other.id != comp.id &&
            other.parentAppointmentId == comp.id &&
            other.status != AppointmentStatus.cancelled);
        if (!alreadyBooked) {
          followUp = comp;
          break;
        }
      }

      Appointment? latestCompleted;
      final allCompleted = list.where((item) => item.status == AppointmentStatus.completed).toList();
      allCompleted.sort((a, b) => b.date.compareTo(a.date));
      if (allCompleted.isNotEmpty) {
        latestCompleted = allCompleted.first;
      }

      if (mounted) {
        setState(() {
          _upcomingAppointment = active.isNotEmpty ? active.first : null;
          _pendingFollowUp = followUp;
          _latestCompletedAppointment = latestCompleted;
          _loadingAppointment = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAppointment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifStore = NotificationStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([PatientSession.instance, notifStore]),
      builder: (context, _) => RefreshIndicator(
        onRefresh: _loadUpcomingAppointment,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                              'Xin chào,',
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
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationScreen(),
                            ),
                          );
                          _loadUpcomingAppointment();
                        },
                        icon: Badge(
                          isLabelVisible: notifStore.unreadCount > 0,
                          label: Text('${notifStore.unreadCount}'),
                          child: const Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.navy],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chăm sóc sức khỏe thông minh',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đặt lịch khám nhanh chóng với các bác sĩ đầu ngành và theo dõi đơn thuốc điện tử tiện lợi.',
                          style: TextStyle(color: Color(0xFFD5F4F5), height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DepartmentScreen(),
                              ),
                            );
                            _loadUpcomingAppointment();
                          },
                          icon: const Icon(Icons.local_hospital_outlined),
                          label: const Text('Tìm chuyên khoa'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const FamilySelectorBar(),
                  const SizedBox(height: 28),
                  const SectionTitle(title: 'Tiện ích nhanh'),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
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
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DoctorListScreen(),
                            ),
                          );
                          _loadUpcomingAppointment();
                        },
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
                        icon: Icons.receipt_long_rounded,
                        title: 'Sổ khám bệnh',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MedicalRecordsScreen(
                                repository: widget.repository,
                              ),
                            ),
                          );
                          _loadUpcomingAppointment();
                        },
                      ),
                      _Action(
                        icon: Icons.medication_rounded,
                        title: 'Từ điển thuốc',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MedicineListScreen(),
                          ),
                        ),
                      ),
                      _Action(
                        icon: Icons.how_to_reg_rounded,
                        title: 'Tiếp đón khám',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReceptionCheckinScreen(
                                repository: widget.repository,
                              ),
                            ),
                          );
                          _loadUpcomingAppointment();
                        },
                      ),
                      _Action(
                        icon: Icons.alarm_rounded,
                        title: 'Nhắc uống thuốc',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MedicationReminderScreen(),
                          ),
                        ),
                      ),
                      _Action(
                        icon: Icons.monitor_heart_rounded,
                        title: 'Chỉ số sinh hiệu',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HealthVitalsScreen(),
                          ),
                        ),
                      ),
                      _Action(
                        icon: Icons.payments_rounded,
                        title: 'Viện phí VietQR',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const InvoiceManagementScreen(),
                          ),
                        ),
                      ),
                      _Action(
                        icon: Icons.family_restroom_rounded,
                        title: 'Hồ sơ gia đình',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FamilyMembersScreen(),
                          ),
                        ),
                      ),
                      _Action(
                        icon: Icons.forum_rounded,
                        title: 'Tư vấn hậu khám',
                        onTap: () {
                          final targetId = _latestCompletedAppointment?.id ?? 'APT-103';
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostCareChatScreen(
                                appointmentId: targetId,
                              ),
                            ),
                          );
                        },
                      ),
                      _Action(
                        icon: Icons.support_agent_outlined,
                        title: 'Hỗ trợ khẩn cấp',
                        onTap: () => _showEmergencySupportDialog(context),
                      ),
                    ],
                  ),
                  if (_pendingFollowUp != null) ...[
                    const SizedBox(height: 24),
                    _buildFollowUpReminderCard(context, _pendingFollowUp!),
                  ],
                  const SizedBox(height: 28),
                  SectionTitle(
                    title: 'Lịch khám sắp tới',
                    action: InkWell(
                      onTap: widget.onViewAllAppointments,
                      child: const Text(
                        'Xem tất cả',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildUpcomingAppointmentSection(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowUpReminderCard(BuildContext context, Appointment apt) {
    final days = apt.followUpDaysRemaining;
    final Color badgeColor;
    final Color badgeBg;
    final String countdownText;

    if (days != null) {
      if (days > 0) {
        badgeColor = const Color(0xFFD97706); // Amber
        badgeBg = const Color(0xFFFEF3C7);
        countdownText = '⏳ Còn $days ngày nữa';
      } else if (days == 0) {
        badgeColor = const Color(0xFFDC2626); // Red
        badgeBg = const Color(0xFFFEE2E2);
        countdownText = '🔔 Hôm nay đến hạn tái khám!';
      } else {
        badgeColor = const Color(0xFF991B1B); // Dark red
        badgeBg = const Color(0xFFFEE2E2);
        countdownText = '⚠️ Quá hạn ${-days} ngày';
      }
    } else {
      badgeColor = const Color(0xFF0284C7);
      badgeBg = const Color(0xFFE0F2FE);
      countdownText = 'Lịch hẹn định kỳ';
    }

    final doctor = doctors.where((d) => d.id == apt.doctorId).firstOrNull ??
        Doctor(
          id: apt.doctorId,
          name: apt.doctorName,
          departmentId: apt.departmentId,
          department: apt.department,
          specialty: apt.specialty,
          experience: 'Bác sĩ chuyên khoa',
          color: const Color(0xFFBDE5E9),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_repeat_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LỊCH HẸN TÁI KHÁM ĐỊNH KỲ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Theo chỉ định của bác sĩ điều trị',
                      style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  countdownText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: doctor.color,
                      child: const Icon(Icons.person,
                          size: 20, color: AppColors.navy),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            apt.doctorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${apt.department} • Ngày hẹn: ${apt.followUpDateLabel ?? "Sắp tới"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (apt.statusNote != null && apt.statusNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Lời dặn: "${apt.statusNote}"',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF451A03),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text(
                    '1 chạm Đặt lịch tái khám',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookAppointmentScreen(
                          doctor: doctor,
                          initialDate: apt.followUpDate,
                          initialReason:
                              'Tái khám theo chỉ định của ${apt.doctorName} (Đợt khám ngày ${apt.dateLabel})',
                          isFollowUp: true,
                          parentAppointmentId: apt.id,
                          repository: widget.repository,
                        ),
                      ),
                    );
                    _loadUpcomingAppointment();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF78350F),
                    side: const BorderSide(color: Color(0xFFD97706)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LabResultsDetailScreen(appointment: apt),
                      ),
                    );
                  },
                  child: const Text(
                    'Xem bệnh án cũ',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointmentSection(BuildContext context) {
    if (_loadingAppointment) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final appointment = _upcomingAppointment;
    if (appointment == null) {
      return InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DoctorListScreen()),
          );
          _loadUpcomingAppointment();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chưa có lịch khám sắp tới',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Đặt lịch hẹn ngay để được thăm khám bởi bác sĩ chuyên khoa.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.mutedText),
            ],
          ),
        ),
      );
    }

    final isConfirmed = appointment.status == AppointmentStatus.confirmed;
    final statusColor = isConfirmed ? AppColors.success : Colors.orange;

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentDetailScreen(
              appointment: appointment,
              repository: widget.repository,
            ),
          ),
        );
        _loadUpcomingAppointment();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.doctorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        appointment.department,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${appointment.time} • ${AppTimezone.date(appointment.date)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Chi tiết',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
            if (appointment.status != AppointmentStatus.cancelled &&
                appointment.status != AppointmentStatus.completed) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DigitalBoardingPassScreen(
                        appointment: appointment,
                        repository: widget.repository,
                      ),
                    ),
                  );
                  _loadUpcomingAppointment();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF0D9488)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appointment.status == AppointmentStatus.checkedIn
                              ? 'Đã tiếp đón • STT: ${appointment.queueNumber?.toString().padLeft(2, '0') ?? '01'} (${appointment.roomNumber ?? 'Phòng 204'})'
                              : 'Mở Thẻ lên phòng khám & QR Check-in',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF0D9488)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEmergencySupportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Hỗ trợ Y tế & Cấp cứu khẩn cấp',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trong trường hợp nguy cấp đe dọa tính mạng, vui lòng gọi cấp cứu 115 ngay lập tức.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.emergency, color: Colors.red),
              ),
              title: const Text(
                'Gọi cấp cứu 115',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              subtitle: const Text('Trung tâm cấp cứu y tế quốc gia'),
              trailing: const Icon(Icons.phone, color: Colors.red),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('tel:115'));
              },
            ),
            const Divider(),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.local_hospital, color: AppColors.primary),
              ),
              title: const Text(
                'Tổng đài Smart Hospital',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('1900 1122 (Tư vấn 24/7)'),
              trailing: const Icon(Icons.phone, color: AppColors.primary),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('tel:19001122'));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

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
