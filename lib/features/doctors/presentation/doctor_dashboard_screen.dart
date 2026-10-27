import '../../../core/repositories/application_backend.dart';
import '../../notifications/data/notification_store.dart';
import '../../notifications/domain/notification_item.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/repositories/auth_repository_provider.dart';
import '../../medicines/data/medicine_repository.dart';
import '../../medical_records/presentation/lab_results_detail_screen.dart';
import '../../vitals/presentation/health_vitals_screen.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/invoice_management_screen.dart';
import '../../teleconsultation/presentation/doctor_teleconsultations_screen.dart';
import '../../teleconsultation/presentation/post_care_chat_screen.dart';
import '../../clinical_intake/data/clinical_intake_repository.dart';
import '../../clinical_intake/presentation/widgets/intake_summary_card.dart';
import '../../vaccination/presentation/vaccination_passport_screen.dart';
import '../domain/doctor.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({
    super.key,
    AppointmentRepository? repository,
    this.doctorId = 'dr-linh',
    this.doctorName = 'BS. Trần Thảo Linh',
    this.department = 'Khoa Tim mạch',
  }) : _providedRepository = repository;

  final AppointmentRepository? _providedRepository;
  AppointmentRepository get repository =>
      _providedRepository ?? ApplicationBackend.repositories.appointments;
  final String doctorId;
  final String doctorName;
  final String department;

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  bool _loading = false;
  List<Appointment> _appointments = [];
  AppointmentStatus? _filterStatus;
  late String _selectedDoctorId = widget.doctorId;
  late String _selectedDoctorName = widget.doctorName;
  late String _selectedDepartment = widget.department;

  @override
  void initState() {
    super.initState();
    AppointmentStore.instance.addListener(_onStoreChanged);
    _loadData();
  }

  @override
  void dispose() {
    AppointmentStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted && !_loading) {
      setState(() {
        final storeItems = AppointmentStore.instance.appointments;
        for (int i = 0; i < _appointments.length; i++) {
          final match = storeItems
              .where((a) => a.id == _appointments[i].id)
              .firstOrNull;
          if (match != null) {
            _appointments[i] = match;
          }
        }
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final items = await widget.repository.getDoctorAppointments(
        doctorId: _selectedDoctorId == 'all' ? null : _selectedDoctorId,
      );

      // Seed sample appointments for local demo if empty
      if (items.isEmpty && widget.repository is LocalAppointmentRepository) {
        final now = AppTimezone.now();
        final sample1 = Appointment(
          id: 'APT-101',
          patientId: 'BN-01',
          patientName: 'Nguyễn Văn An',
          doctorId: _selectedDoctorId == 'all' ? 'dr-linh' : _selectedDoctorId,
          doctorName: _selectedDoctorName,
          specialty: 'Tim mạch',
          department: _selectedDepartment,
          date: now,
          time: '08:30',
          reason: 'Đau tức ngực trái khi vận động mạnh',
          status: AppointmentStatus.pending,
          createdAt: now.subtract(const Duration(hours: 2)),
        );
        final sample2 = Appointment(
          id: 'APT-102',
          patientId: 'BN-02',
          patientName: 'Trần Thị Mai',
          doctorId: _selectedDoctorId == 'all' ? 'dr-linh' : _selectedDoctorId,
          doctorName: _selectedDoctorName,
          specialty: 'Tim mạch',
          department: _selectedDepartment,
          date: now,
          time: '09:30',
          reason: 'Tái khám định kỳ tăng huyết áp',
          status: AppointmentStatus.confirmed,
          createdAt: now.subtract(const Duration(hours: 5)),
        );
        final sample3 = Appointment(
          id: 'APT-103',
          patientId: 'BN-03',
          patientName: 'Lê Hoàng Nam',
          doctorId: _selectedDoctorId == 'all' ? 'dr-linh' : _selectedDoctorId,
          doctorName: _selectedDoctorName,
          specialty: 'Tim mạch',
          department: _selectedDepartment,
          date: now.subtract(const Duration(days: 1)),
          time: '14:00',
          reason: 'Khó thở về đêm, hồi hộp',
          status: AppointmentStatus.completed,
          diagnosis: 'Rối loạn nhịp tim nhẹ, stress kéo dài',
          prescription: '1. Concor 2.5mg - 1 viên/ngày buổi sáng\n2. Magne B6 - 2 viên/ngày chia 2 lần',
          statusNote: 'Hạn chế thức khuya, tái khám sau 2 tuần',
          createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        );
        AppointmentStore.instance.addAppointment(sample1);
        AppointmentStore.instance.addAppointment(sample2);
        AppointmentStore.instance.addAppointment(sample3);

        final reloaded = await widget.repository.getDoctorAppointments(
          doctorId: _selectedDoctorId == 'all' ? null : _selectedDoctorId,
        );
        if (mounted) setState(() => _appointments = reloaded);
      } else {
        if (mounted) setState(() => _appointments = items);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải danh sách lịch khám.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDoctorPicker() {
    if (widget.repository is RemoteAppointmentRepository) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_alt_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Chọn Bác sĩ làm việc',
                    style: Theme.of(ctx).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.domain, color: Colors.white, size: 20),
              ),
              title: const Text(
                'Toàn viện (Xem tất cả bác sĩ)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Hiển thị lịch khám của tất cả các chuyên khoa',
              ),
              selected: _selectedDoctorId == 'all',
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedDoctorId = 'all';
                  _selectedDoctorName = 'Ban Giám đốc & Toàn viện';
                  _selectedDepartment = 'Tất cả chuyên khoa';
                });
                _loadData();
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: doctors.length,
                itemBuilder: (ctx, index) {
                  final doc = doctors[index];
                  final isSelected = _selectedDoctorId == doc.id;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: doc.color,
                      child: Text(
                        doc.name.replaceFirst('BS. ', '').substring(0, 1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    title: Text(
                      doc.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('${doc.department} • ${doc.specialty}'),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedDoctorId = doc.id;
                        _selectedDoctorName = doc.name;
                        _selectedDepartment = doc.department;
                      });
                      _loadData();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    Appointment appointment,
    AppointmentStatus newStatus, {
    String? note,
  }) async {
    try {
      final updated = await widget.repository.updateAppointmentStatus(
        appointment.id,
        newStatus,
        note: note,
      );
      if (mounted) {
        setState(() {
          final idx = _appointments.indexWhere((a) => a.id == appointment.id);
          if (idx >= 0) _appointments[idx] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == AppointmentStatus.confirmed
                  ? 'Đã xác nhận lịch khám của ${appointment.patientName}'
                  : 'Đã hủy lịch khám',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Bad state: ', '')}'),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản bác sĩ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await authRepository.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterStatus == null
        ? _appointments
        : _appointments.where((a) => a.status == _filterStatus).toList();

    final pendingCount = _appointments
        .where((a) => a.status == AppointmentStatus.pending)
        .length;
    final confirmedCount = _appointments
        .where((a) => a.status == AppointmentStatus.confirmed)
        .length;
    final checkedInCount = _appointments
        .where((a) => a.status == AppointmentStatus.checkedIn)
        .length;
    final completedCount = _appointments
        .where((a) => a.status == AppointmentStatus.completed)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cổng Bác sĩ (Doctor Portal)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Chọn Bác sĩ làm việc',
            onPressed: widget.repository is RemoteAppointmentRepository
                ? null
                : _showDoctorPicker,
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_rounded),
            tooltip: 'Quản lý Viện phí & Đối soát',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const InvoiceManagementScreen(),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Tư vấn Hậu khám (7 ngày)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DoctorTeleconsultationsScreen(
                    doctorId: _selectedDoctorId,
                    doctorName: _selectedDoctorName,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.medical_services,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDoctorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$_selectedDepartment • Đang trực',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap:
                                    widget.repository
                                        is RemoteAppointmentRepository
                                    ? null
                                    : _showDoctorPicker,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Đổi BS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Statistics Row
              const SectionTitle(title: 'Tổng quan hôm nay'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statCard(
                    title: 'Chờ duyệt',
                    count: pendingCount,
                    color: Colors.orange,
                    icon: Icons.pending_actions,
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    title: 'Đã duyệt',
                    count: confirmedCount,
                    color: Colors.blue,
                    icon: Icons.event_available,
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    title: 'Đã hoàn thành',
                    count: completedCount,
                    color: AppColors.success,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Live Clinic Calling & In-Consultation Station
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PHÒNG KHÁM 204 • CA SÁNG',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.campaign_rounded,
                          color: Color(0xFF0D9488),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Hàng đợi tiếp đón trực tiếp',
                          style: TextStyle(
                            color: Color(0xFF0D9488),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (checkedInCount > 0) ...[
                      Builder(
                        builder: (ctx) {
                          final nextPatient = _appointments.firstWhere(
                            (a) => a.status == AppointmentStatus.checkedIn,
                          );
                          return Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF0D9488)
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  nextPatient.queueNumber != null
                                      ? '${nextPatient.queueNumber}'.padLeft(
                                          2,
                                          '0',
                                        )
                                      : '01',
                                  style: const TextStyle(
                                    color: Color(0xFF0D9488),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'STT ${nextPatient.queueNumber ?? 1}: ${nextPatient.patientName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'Đang đợi ngoài sảnh • Giờ khám: ${nextPatient.time}',
                                      style: const TextStyle(
                                        color: AppColors.mutedText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.volume_up_rounded,
                                  size: 18,
                                ),
                                label: const Text('Gọi vào khám'),
                                onPressed: () async {
                                  NotificationStore.instance.addNotification(
                                    title: 'Mời vào phòng khám',
                                    body:
                                        'Mời bệnh nhân ${nextPatient.patientName} (STT: ${nextPatient.queueNumber?.toString().padLeft(2, '0') ?? '01'}) vào Phòng 204 gặp BS. Trần Thảo Linh.',
                                    type: NotificationType.appointment,
                                    referenceId: nextPatient.id,
                                  );

                                  final updated = await Navigator.of(context)
                                      .push<Appointment>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DoctorExaminationScreen(
                                                appointment: nextPatient,
                                                repository: widget.repository,
                                              ),
                                        ),
                                      );
                                  if (updated != null && mounted) {
                                    setState(() {
                                      final idx = _appointments.indexWhere(
                                        (a) => a.id == updated.id,
                                      );
                                      if (idx >= 0) {
                                        _appointments[idx] = updated;
                                      }
                                      if (_filterStatus != null &&
                                          _filterStatus !=
                                              AppointmentStatus.completed) {
                                        _filterStatus = null;
                                      }
                                    });
                                    _loadData();
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Chưa có bệnh nhân đợi ngoài sảnh. Hệ thống sẵn sàng nhận ca tiếp theo.',
                              style: TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Filter Tabs
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(null, 'Tất cả (${_appointments.length})'),
                          const SizedBox(width: 8),
                          _filterChip(
                            AppointmentStatus.pending,
                            'Chờ duyệt ($pendingCount)',
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            AppointmentStatus.confirmed,
                            'Đã duyệt ($confirmedCount)',
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            AppointmentStatus.checkedIn,
                            'Đã đến khám ($checkedInCount)',
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            AppointmentStatus.completed,
                            'Đã hoàn thành ($completedCount)',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Appointments List
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 48,
                        color: AppColors.mutedText.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Không có lịch khám nào trong danh mục này.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map((item) => _buildAppointmentCard(item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
        ],
      ),
    ),
  );

  Widget _filterChip(AppointmentStatus? status, String label) {
    final selected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filterStatus = status),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.text,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment item) {
    Color statusColor;
    switch (item.status) {
      case AppointmentStatus.pending:
        statusColor = Colors.orange;
        break;
      case AppointmentStatus.confirmed:
        statusColor = Colors.blue;
        break;
      case AppointmentStatus.checkedIn:
        statusColor = const Color(0xFF0D9488);
        break;
      case AppointmentStatus.completed:
        statusColor = AppColors.success;
        break;
      case AppointmentStatus.cancelled:
        statusColor = Colors.grey;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.patientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (item.isFollowUp) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFCD34D),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_repeat_rounded,
                                  size: 11,
                                  color: Color(0xFFD97706),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'TÁI KHÁM',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Mã lịch: ${item.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.time} • ${AppTimezone.date(item.date)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (item.queueNumber != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'STT: ${item.queueNumber.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Lý do: ${item.reason}',
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
          if (item.diagnosis != null && item.diagnosis!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chẩn đoán:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                  Text(item.diagnosis!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Action Buttons based on status
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HealthVitalsScreen(
                        patientId: item.patientId.isNotEmpty
                            ? item.patientId
                            : 'patient-1',
                        isDoctorView: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.monitor_heart_outlined,
                  size: 16,
                  color: Color(0xFF0D9488),
                ),
                label: const Text(
                  'Sinh hiệu',
                  style: TextStyle(color: Color(0xFF0D9488), fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              if (item.status == AppointmentStatus.pending) ...[
                OutlinedButton(
                  onPressed: () => _updateStatus(
                    item,
                    AppointmentStatus.cancelled,
                    note: 'Bác sĩ bận việc đột xuất',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Từ chối'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      _updateStatus(item, AppointmentStatus.confirmed),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Xác nhận lịch'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ] else if (item.status == AppointmentStatus.confirmed ||
                  item.status == AppointmentStatus.checkedIn) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.of(context)
                        .push<Appointment>(
                          MaterialPageRoute(
                            builder: (_) => DoctorExaminationScreen(
                              appointment: item,
                              repository: widget.repository,
                            ),
                          ),
                        );
                    if (updated != null && mounted) {
                      setState(() {
                        final idx = _appointments.indexWhere(
                          (a) => a.id == updated.id,
                        );
                        if (idx >= 0) _appointments[idx] = updated;
                        if (_filterStatus != null &&
                            _filterStatus != AppointmentStatus.completed) {
                          _filterStatus = null;
                        }
                      });
                      _loadData();
                    }
                  },
                  icon: const Icon(Icons.medical_services, size: 18),
                  label: const Text('Tiến hành khám'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ] else if (item.status == AppointmentStatus.completed) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DoctorExaminationDetailScreen(appointment: item),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Xem bệnh án & đơn thuốc'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostCareChatScreen(
                          appointmentId: item.id,
                          isDoctorView: true,
                          currentUserId: item.doctorId,
                          currentUserName: item.doctorName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Tư vấn hậu khám'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class DoctorExaminationScreen extends StatefulWidget {
  const DoctorExaminationScreen({
    super.key,
    required this.appointment,
    required this.repository,
  });

  final Appointment appointment;
  final AppointmentRepository repository;

  @override
  State<DoctorExaminationScreen> createState() =>
      _DoctorExaminationScreenState();
}

class _DoctorExaminationScreenState extends State<DoctorExaminationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _adviceController = TextEditingController();
  bool _submitting = false;
  bool _labOrdered = false;
  bool _hasAllergyRisk = false;
  DateTime? _selectedFollowUpDate;
  int? _selectedFollowUpDays;
  final Set<String> _selectedLabs = {
    'Tổng phân tích tế bào máu (CBC)',
    'Điện tâm đồ ECG 12 chuyển đạo',
  };

  @override
  void initState() {
    super.initState();
    _prescriptionController.addListener(() {
      final text = _prescriptionController.text.toLowerCase();
      final hasRisk =
          text.contains('penicillin') ||
          text.contains('amoxicillin') ||
          text.contains('augmentin');
      if (hasRisk != _hasAllergyRisk) {
        setState(() => _hasAllergyRisk = hasRisk);
      }
    });
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _prescriptionController.dispose();
    _adviceController.dispose();
    super.dispose();
  }

  Future<void> _showMedicineSelector() async {
    final meds = LocalMedicineRepository.sampleMedicines;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.medication_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Chọn thuốc từ Danh mục Bệnh viện',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: meds.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final m = meds[index];
                  return ListTile(
                    title: Text(
                      m.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${m.activeIngredient} • ${m.dosageInstructions}',
                    ),
                    trailing: FilledButton.tonal(
                      child: const Text('Kê đơn'),
                      onPressed: () {
                        final current = _prescriptionController.text.trim();
                        final count = current.isEmpty
                            ? 1
                            : '\n'.allMatches(current).length + 2;
                        final line =
                            '$count. ${m.name} (${m.activeIngredient}) - ${m.dosageInstructions.split('.').first}';
                        _prescriptionController.text = current.isEmpty
                            ? line
                            : '$current\n$line';
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyTemplate(String diagnosis, String prescription, String advice) {
    setState(() {
      _diagnosisController.text = diagnosis;
      _prescriptionController.text = prescription;
      _adviceController.text = advice;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập Chẩn đoán bệnh trước khi hoàn tất ca khám!',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      String advice = _adviceController.text.trim();
      if (_selectedFollowUpDate != null) {
        final fText =
            'Hẹn tái khám ngày ${AppTimezone.date(_selectedFollowUpDate!)}';
        if (!advice.contains(fText)) {
          advice = advice.isEmpty ? fText : '$advice\n• $fText';
        }
      }
      if (_labOrdered && _selectedLabs.isNotEmpty) {
        final labStr =
            'Kết quả CLS: ${_selectedLabs.join(", ")} (Chỉ số sinh hóa & huyết học trong giới hạn bình thường).';
        advice = advice.isEmpty ? labStr : '$advice\n• $labStr';
      }

      final updated = await widget.repository.updateAppointmentStatus(
        widget.appointment.id,
        AppointmentStatus.completed,
        diagnosis: _diagnosisController.text.trim(),
        prescription: _prescriptionController.text.trim(),
        note: advice,
        followUpDate: _selectedFollowUpDate,
      );
      AppointmentStore.instance.replaceAppointment(updated);

      final paymentRepo = LocalPaymentRepository();
      if (_labOrdered && _selectedLabs.isNotEmpty) {
        await paymentRepo.createOrUpdateLabInvoice(
          widget.appointment.id,
          _selectedLabs.toList(),
        );
      }
      if (_prescriptionController.text.trim().isNotEmpty) {
        await paymentRepo.getOrCreatePharmacyInvoice(widget.appointment.id);
      }

      final fNote = _selectedFollowUpDate != null
          ? ' Bác sĩ có lịch hẹn tái khám ngày ${AppTimezone.date(_selectedFollowUpDate!)}.'
          : '';
      NotificationStore.instance.addNotification(
        title: 'Đã có kết quả khám & Đơn thuốc',
        body:
            'BS. Trần Thảo Linh đã hoàn tất ca khám cho ${widget.appointment.patientName}.$fNote Vui lòng kiểm tra đơn thuốc và làm thủ tục thanh toán viện phí.',
        type: NotificationType.prescription,
        referenceId: widget.appointment.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hoàn tất ca khám thành công!')),
        );
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Bad state: ', '')}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khám & Kê đơn thuốc')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Summary Card with Allergy Alert & Vitals
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        widget.appointment.patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Lịch: ${widget.appointment.time}',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Text(
                    'Triệu chứng / Lý do: ${widget.appointment.reason}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  // Red Allergy Alert Banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CẢNH BÁO TIỀN SỬ DỊ ỨNG: Dị ứng Penicillin, Amoxicillin (Khó thở, phát ban cấp).',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.appointment.isFollowUp ||
                      widget.appointment.parentAppointmentId != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LabResultsDetailScreen(
                              appointmentId:
                                  widget.appointment.parentAppointmentId ??
                                  widget.appointment.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.event_repeat_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'CA TÁI KHÁM THEO CHỈ ĐỊNH: Chạm để xem Bệnh án & Kết quả Xét nghiệm đợt trước',
                                style: TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Triage Vitals Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'Huyết áp: 138/88 mmHg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text('•', style: TextStyle(color: Colors.grey)),
                        Text(
                          'Mạch: 78 bpm',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text('•', style: TextStyle(color: Colors.grey)),
                        Text(
                          'SpO2: 98%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text('•', style: TextStyle(color: Colors.grey)),
                        Text(
                          'BMI: 23.5',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.history_edu_rounded, size: 18),
                      label: const Text(
                        'Xem lịch sử khám & đơn thuốc cũ của bệnh nhân',
                      ),
                      onPressed: () => _showPatientMedicalHistoryModal(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Pre-visit Clinical Intake Summary for Doctor Review
            Builder(
              builder: (context) {
                final intake = ClinicalIntakeStore.instance.getByAppointmentId(
                  widget.appointment.id,
                );
                if (intake != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IntakeSummaryCard(intake: intake, isDoctorView: true),
                      const SizedBox(height: 18),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Paraclinical Diagnostic Orders Section
            SectionTitle(
              title: 'Chỉ định Cận lâm sàng (CLS)',
              action: TextButton.icon(
                icon: Icon(
                  _labOrdered ? Icons.check_circle : Icons.science_outlined,
                  size: 16,
                ),
                label: Text(
                  _labOrdered
                      ? 'Đã chỉ định & Tạo phí CLS'
                      : 'Chỉ định & Tạo phí CLS',
                ),
                onPressed: () async {
                  if (_selectedLabs.isEmpty) {
                    _selectedLabs.add('Tổng phân tích tế bào máu (CBC)');
                  }
                  await LocalPaymentRepository().createOrUpdateLabInvoice(
                    widget.appointment.id,
                    _selectedLabs.toList(),
                  );
                  await widget.repository.updateAppointmentStatus(
                    widget.appointment.id,
                    widget.appointment.status,
                    note: 'Chỉ định CLS: ${_selectedLabs.join(", ")}',
                  );
                  if (mounted) {
                    setState(() => _labOrdered = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã phát hành Chỉ định CLS & Hóa đơn xét nghiệm. Bệnh nhân cần thanh toán phí CLS để nhận Mã QR xét nghiệm!',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                    'Tổng phân tích tế bào máu (CBC)',
                    'Điện tâm đồ ECG 12 chuyển đạo',
                    'Siêu âm tim Doppler màu',
                    'Chụp X-quang tim phổi (CXR)',
                    'Sinh hóa máu (Glucose, Creatinine)',
                  ].map((lab) {
                    final isSelected = _selectedLabs.contains(lab);
                    return FilterChip(
                      label: Text(
                        lab,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.text,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedLabs.add(lab);
                          } else {
                            _selectedLabs.remove(lab);
                          }
                        });
                      },
                    );
                  }).toList(),
            ),
            if (_labOrdered) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          color: Color(0xFF0D9488),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'KẾT QUẢ CẬN LÂM SÀNG TỪ PHÒNG XÉT NGHIỆM & CĐHA:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Điện tâm đồ ECG: Nhịp xoang đều 78ck/p, trục trung gian, không thiếu máu cơ tim cấp.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    Text(
                      '• Siêu âm tim: Buồng tim kích thước bình thường, EF 62%, hở van 2 lá sinh lý 1/4.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    Text(
                      '• Công thức máu: WBC 6.8 G/L, RBC 4.6 T/L, Hb 142 g/L (Bình thường).',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    Text(
                      '• Sinh hóa máu: Glucose đói 5.3 mmol/L, Creatinine 76 umol/L (Chức năng thận tốt).',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            const SectionTitle(title: 'Mẫu kê nhanh (Templates)'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.flash_on,
                      size: 16,
                      color: Colors.orange,
                    ),
                    label: const Text('Cảm cúm / Viêm họng'),
                    onPressed: () => _applyTemplate(
                      'Viêm đường hô hấp trên cấp tính, sốt nhẹ',
                      '1. Paracetamol 500mg - 1 viên x 3 lần/ngày sau ăn khi sốt\n2. Vitamin C 500mg - 1 viên/ngày buổi sáng',
                      'Uống nhiều nước ấm, súc họng nước muối. Tái khám sau 3 ngày nếu sốt không giảm.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.flash_on,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: const Text('Tăng huyết áp'),
                    onPressed: () => _applyTemplate(
                      'Tăng huyết áp vô căn độ 1',
                      '1. Amlodipine 5mg - 1 viên/ngày vào 8h sáng\n2. Aspirin 81mg - 1 viên/ngày sau ăn',
                      'Ăn nhạt, hạn chế mỡ động vật, đo huyết áp mỗi sáng. Tái khám sau 1 tháng.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.flash_on,
                      size: 16,
                      color: Colors.green,
                    ),
                    label: const Text('Khám sức khỏe tốt'),
                    onPressed: () => _applyTemplate(
                      'Hiện tại chưa phát hiện bất thường, sức khỏe tốt',
                      '1. Multivitamin tổng hợp - 1 viên/ngày sau ăn sáng',
                      'Duy trì chế độ ăn lành mạnh và tập luyện 30 phút mỗi ngày.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SectionTitle(title: 'Kết quả khám bệnh'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diagnosisController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Chẩn đoán bệnh *',
                hintText: 'Ví dụ: Viêm họng cấp / Huyết áp ổn định...',
                alignLabelWithHint: true,
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Vui lòng nhập chẩn đoán'
                  : null,
            ),
            const SizedBox(height: 18),

            SectionTitle(
              title: 'Đơn thuốc điện tử',
              action: TextButton.icon(
                onPressed: _showMedicineSelector,
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('Chọn từ kho dược'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prescriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Toa thuốc kê cho bệnh nhân',
                hintText: 'Ví dụ:\n1. Paracetamol 500mg - 2 viên/ngày sau ăn\n2. Vitamin C 500mg - 1 viên/ngày',
                alignLabelWithHint: true,
              ),
            ),
            if (_hasAllergyRisk) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.report_problem_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🚨 CẢNH BÁO AN TOÀN DƯỢC LÂM SÀNG: Toa thuốc chứa hoạt chất dị ứng (Penicillin/Amoxicillin)! Vui lòng đổi thuốc theo phác đồ an toàn.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            const SectionTitle(title: 'Lời dặn của bác sĩ'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adviceController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lời dặn / Hẹn ngày tái khám',
                hintText: 'Ví dụ: Uống nhiều nước, ăn thanh đạm.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),

            const SectionTitle(title: 'Kế hoạch Hẹn ngày Tái khám'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('7 ngày nữa'),
                  selected: _selectedFollowUpDays == 7,
                  onSelected: (val) {
                    setState(() {
                      _selectedFollowUpDays = val ? 7 : null;
                      _selectedFollowUpDate = val
                          ? DateTime.now().add(const Duration(days: 7))
                          : null;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('14 ngày nữa'),
                  selected: _selectedFollowUpDays == 14,
                  onSelected: (val) {
                    setState(() {
                      _selectedFollowUpDays = val ? 14 : null;
                      _selectedFollowUpDate = val
                          ? DateTime.now().add(const Duration(days: 14))
                          : null;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('1 tháng nữa'),
                  selected: _selectedFollowUpDays == 30,
                  onSelected: (val) {
                    setState(() {
                      _selectedFollowUpDays = val ? 30 : null;
                      _selectedFollowUpDate = val
                          ? DateTime.now().add(const Duration(days: 30))
                          : null;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(
                    _selectedFollowUpDate != null &&
                            _selectedFollowUpDays == null
                        ? AppTimezone.date(_selectedFollowUpDate!)
                        : 'Chọn ngày',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedFollowUpDays = null;
                        _selectedFollowUpDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
            if (_selectedFollowUpDate != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_repeat_rounded,
                      color: Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bác sĩ đặt lịch hẹn tái khám: ${AppTimezone.date(_selectedFollowUpDate!)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        _selectedFollowUpDate = null;
                        _selectedFollowUpDays = null;
                      }),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),

            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                _submitting ? 'Đang lưu kết quả...' : 'Hoàn tất ca khám',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _showPatientMedicalHistoryModal(BuildContext context) {
    final pastVisits = AppointmentStore.instance.appointments
        .where(
          (a) =>
              a.id != widget.appointment.id &&
              a.status == AppointmentStatus.completed &&
              (a.patientId == widget.appointment.patientId ||
                  a.patientName == widget.appointment.patientName),
        )
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_edu_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LỊCH SỬ BỆNH ÁN CŨ - ${widget.appointment.patientName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        const Text(
                          'Tra cứu bệnh sử, chẩn đoán cũ & đơn thuốc đã từng điều trị',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ TIỀN SỬ DỊ ỨNG & BỆNH NỀN:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Dị ứng thuốc: Nhóm Penicillin, Amoxicillin (Khó thở, phát ban cấp năm 2024)',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Bệnh nền: Tăng huyết áp vô căn 3 năm, viêm trợt dạ dày nhẹ',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.vaccines_rounded, size: 18),
                      label: const Text('Xem Sổ Tiêm Chủng & Hộ Chiếu Vắc-Xin'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const VaccinationPassportScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (pastVisits.isEmpty) ...[
                    _buildPastVisitCard(
                      date: '15/09/2026',
                      doctor: 'BS. Trần Thảo Linh (Khoa Tim mạch)',
                      diagnosis:
                          'Tăng huyết áp độ 1, đau thắt ngực nhẹ khi gắng sức',
                      prescription: '1. Amlodipine 5mg - 1 viên/ngày 8h sáng\n2. Aspirin 81mg - 1 viên/ngày sau ăn',
                      advice: 'Hạn chế ăn mặn, tập thể dục nhẹ nhàng 30p mỗi ngày, tái khám sau 1 tháng.',
                    ),
                  ] else ...[
                    ...pastVisits.map(
                      (v) => _buildPastVisitCard(
                        date: '${v.dateLabel} lúc ${v.time}',
                        doctor: '${v.doctorName} (${v.department})',
                        diagnosis: v.diagnosis ?? 'Khám tổng quát định kỳ',
                        prescription: v.prescription ?? 'Chưa có đơn thuốc',
                        advice: v.statusNote ?? '',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastVisitCard({
    required String date,
    required String doctor,
    required String diagnosis,
    required String prescription,
    required String advice,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Ngày khám: $date',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Đã hoàn tất',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bác sĩ: $doctor',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Divider(height: 12),
          Text(
            '• Chẩn đoán: $diagnosis',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '• Đơn thuốc cũ:\n$prescription',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          if (advice.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '• Lời dặn cũ: $advice',
              style: const TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text(
                'Kê lại đơn thuốc này',
                style: TextStyle(fontSize: 12),
              ),
              onPressed: () {
                _prescriptionController.text = prescription;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép đơn thuốc cũ vào toa hiện tại!'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorExaminationDetailScreen extends StatelessWidget {
  const DoctorExaminationDetailScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết bệnh án & Đơn thuốc')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bệnh nhân: ${appointment.patientName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          appointment.status.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Mã lịch hẹn: ${appointment.id}',
                style: const TextStyle(color: AppColors.mutedText),
              ),
              Text(
                'Thời gian khám: ${appointment.time} - ${AppTimezone.date(appointment.date)}',
              ),
              const SizedBox(height: 8),
              Text('Lý do khám: ${appointment.reason}'),
            ],
          ),
        ),
        Builder(
          builder: (context) {
            final intake = ClinicalIntakeStore.instance.getByAppointmentId(
              appointment.id,
            );
            if (intake != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  IntakeSummaryCard(intake: intake, isDoctorView: true),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(height: 16),
        _infoCard(
          title: 'Chẩn đoán của Bác sĩ',
          icon: Icons.assignment_outlined,
          content: appointment.diagnosis ?? 'Chưa ghi chẩn đoán',
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        _infoCard(
          title: 'Đơn thuốc đã kê',
          icon: Icons.medication_outlined,
          content: appointment.prescription ?? 'Không kê đơn',
          color: AppColors.success,
        ),
        if (appointment.statusNote != null &&
            appointment.statusNote!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _infoCard(
            title: 'Lời dặn',
            icon: Icons.tips_and_updates_outlined,
            content: appointment.statusNote!,
            color: Colors.amber.shade800,
          ),
        ],
      ],
    ),
  );

  Widget _infoCard({
    required String title,
    required IconData icon,
    required String content,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        Text(content, style: const TextStyle(fontSize: 15, height: 1.4)),
      ],
    ),
  );
}
