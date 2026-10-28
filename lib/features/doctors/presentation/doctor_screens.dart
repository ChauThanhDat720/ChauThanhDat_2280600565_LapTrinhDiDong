import '../../../core/realtime/hospital_realtime_service.dart';
import '../../../core/config/aws_config.dart';
import '../../../core/repositories/application_backend.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../appointments/presentation/appointment_success_screen.dart';
import '../../departments/domain/department.dart' as hospital;
import '../domain/doctor.dart';
import '../../../core/session/patient_session.dart';
import '../../family/presentation/family_profile_manager.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key, this.initialDepartmentId});
  final String? initialDepartmentId;

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  late String? _departmentId = widget.initialDepartmentId;
  String _query = '';
  List<Doctor> _catalog = doctors;
  bool _loading = false;
  Object? _catalogError;
  @override
  void initState() {
    super.initState();
    if (AwsConfig.useAws) _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _catalogError = null;
    });
    try {
      final catalog = await ApplicationBackend.repositories.doctors
          .getDoctors();
      if (mounted) setState(() => _catalog = catalog);
    } catch (error) {
      if (mounted) setState(() => _catalogError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bác sĩ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_catalogError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bác sĩ')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không thể tải danh sách bác sĩ.'),
              TextButton(onPressed: _loadCatalog, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final query = _query.trim().toLowerCase();
    final visible = _catalog.where((doctor) {
      final matchesDepartment =
          _departmentId == null || doctor.departmentId == _departmentId;
      final matchesQuery =
          query.isEmpty ||
          doctor.name.toLowerCase().contains(query) ||
          doctor.specialty.toLowerCase().contains(query) ||
          doctor.department.toLowerCase().contains(query);
      return matchesDepartment && matchesQuery;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Bác sĩ')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên, chuyên khoa',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: hospital.departments.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final department = index == 0
                          ? null
                          : hospital.departments[index - 1];
                      return ChoiceChip(
                        label: Text(department?.name ?? 'Tất cả'),
                        selected: _departmentId == department?.id,
                        onSelected: (_) =>
                            setState(() => _departmentId = department?.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${visible.length} bác sĩ phù hợp',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: visible.isEmpty
                      ? const _DoctorEmpty()
                      : ListView.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _DoctorCard(
                            doctor: visible[index],
                            onTap: () async {
                              final appointment = await Navigator.of(context)
                                  .push<Appointment>(
                                    MaterialPageRoute(
                                      builder: (_) => DoctorDetailScreen(
                                        doctor: visible[index],
                                      ),
                                    ),
                                  );
                              if (appointment != null && context.mounted) {
                                Navigator.pop(context, appointment);
                              }
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({super.key, required this.doctor});
  final Doctor doctor;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết bác sĩ')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: doctor.color,
                      child: const Icon(
                        Icons.person,
                        color: AppColors.navy,
                        size: 42,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctor.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            doctor.specialty,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            doctor.experience,
                            style: const TextStyle(color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Giới thiệu'),
              const SizedBox(height: 10),
              Text(
                '${doctor.name} chuyên tư vấn và khám điều trị tại khoa ${doctor.department}.',
                style: const TextStyle(color: AppColors.mutedText, height: 1.5),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Thông tin khám'),
              const SizedBox(height: 12),
              InfoTile(
                icon: Icons.local_hospital_outlined,
                title: doctor.department,
                subtitle: 'Smart Hospital • Phòng khám ngoại trú',
              ),
              const SizedBox(height: 10),
              const InfoTile(
                icon: Icons.payments_outlined,
                title: 'Phí khám',
                subtitle: '300.000 VNĐ',
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push<Appointment>(
                    MaterialPageRoute(
                      builder: (_) => BookAppointmentScreen(doctor: doctor),
                    ),
                  );
                  if (result != null && context.mounted) {
                    Navigator.pop(context, result);
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Đặt lịch khám'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({
    super.key,
    required this.doctor,
    AppointmentRepository? repository,
    this.nowProvider,
    this.initialDate,
    this.initialReason,
    this.isFollowUp = false,
    this.parentAppointmentId,
  }) : _providedRepository = repository;
  final Doctor doctor;
  final AppointmentRepository? _providedRepository;
  AppointmentRepository get repository =>
      _providedRepository ?? ApplicationBackend.repositories.appointments;
  final DateTime Function()? nowProvider;
  final DateTime? initialDate;
  final String? initialReason;
  final bool isFollowUp;
  final String? parentAppointmentId;
  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _reason = TextEditingController();
  DateTime? _selectedDay;
  String? _time;
  bool _submitting = false;
  bool _loadingSlots = false;
  Object? _slotError;
  List<AppointmentSlot> _slots = const [];

  @override
  void initState() {
    super.initState();
    if (widget.initialReason != null && widget.initialReason!.isNotEmpty) {
      _reason.text = widget.initialReason!;
    }
    if (widget.initialDate != null) {
      _selectedDay = widget.initialDate;
      _loadSlots(widget.initialDate!);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = widget.nowProvider?.call() ?? AppTimezone.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Chọn ngày khám',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedDay = selected;
        _time = null;
        _slots = const [];
        _slotError = null;
      });
      await _loadSlots(selected);
    }
  }

  Future<void> _loadSlots(DateTime date) async {
    setState(() {
      _loadingSlots = true;
      _slotError = null;
    });
    try {
      final slots = await widget.repository.getAvailableSlots(
        widget.doctor.id,
        date,
      );
      if (mounted) setState(() => _slots = slots);
    } catch (error) {
      if (mounted) setState(() => _slotError = error);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _submit() async {
    if (_submitting) return;
    if (_selectedDay == null) {
      _showMessage('Vui lòng chọn ngày khám');
      return;
    }
    if (_time == null) {
      _showMessage('Vui lòng chọn khung giờ');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      _showMessage('Vui lòng nhập lý do khám');
      return;
    }
    if (_reason.text.trim().length > 500) {
      _showMessage('Lý do khám không hợp lệ');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đặt lịch'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bác sĩ: ${widget.doctor.name}'),
              Text('Khoa: ${widget.doctor.department}'),
              Text('Ngày: ${_dateLabel(_selectedDay!)}'),
              Text('Giờ: $_time'),
              const SizedBox(height: 12),
              const Text(
                'Lý do:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(_reason.text.trim()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final currentMember = FamilyProfileManager.instance.activeMember;
      final sessionName = PatientSession.instance.name.isNotEmpty
          ? PatientSession.instance.name
          : 'Nguyễn Văn An';
      final patientName = (currentMember == null || currentMember.isSelf)
          ? sessionName
          : '${currentMember.fullName} (${currentMember.relationshipLabel})';

      final appointment = await widget.repository.createAppointment(
        Appointment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          doctorId: widget.doctor.id,
          doctorName: widget.doctor.name,
          specialty: widget.doctor.specialty,
          department: widget.doctor.department,
          date: _selectedDay!,
          time: _time!,
          reason: _reason.text.trim(),
          patientId: currentMember?.id ?? '',
          patientName: patientName,
          status: AppointmentStatus.confirmed,
          isFollowUp: widget.isFollowUp,
          parentAppointmentId: widget.parentAppointmentId,
        ),
      );
      HospitalRealtimeService.instance.notifyAppointmentCreated(appointment);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppointmentSuccessScreen(
            appointment: appointment,
            repository: widget.repository,
          ),
        ),
      );
      return;
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Bad state: ', '');
        _showMessage(
          message.contains('Khung giờ')
              ? 'Khung giờ này không còn khả dụng. Vui lòng chọn giờ khác.'
              : message,
        );
        if (message.contains('Khung giờ')) await _loadSlots(_selectedDay!);
      }
      if (mounted) setState(() => _submitting = false);
      return;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đặt lịch khám')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isFollowUp) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.event_repeat_rounded,
                        color: Color(0xFFD97706),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LỊCH TÁI KHÁM THEO CHỈ ĐỊNH',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bác sĩ ${widget.doctor.name} đã chỉ định bạn tái khám vào ngày ${widget.initialDate != null ? _dateLabel(widget.initialDate!) : "sắp tới"}. Hồ sơ bệnh án và lịch sử xét nghiệm cũ sẽ được tự động liên kết.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF78350F),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              InfoTile(
                icon: Icons.medical_services_outlined,
                title: widget.doctor.name,
                subtitle:
                    '${widget.doctor.specialty} • ${widget.doctor.department}',
              ),
              const SizedBox(height: 26),
              const SectionTitle(title: 'Ngày khám'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _selectedDay == null
                      ? 'Chọn ngày khám'
                      : _dateLabel(_selectedDay!),
                ),
              ),
              const SizedBox(height: 26),
              const SectionTitle(title: 'Chọn khung giờ'),
              const SizedBox(height: 12),
              if (_selectedDay == null)
                const Text('Hãy chọn ngày để xem khung giờ.')
              else if (_loadingSlots)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Đang tải giờ khám...'),
                    ],
                  ),
                )
              else if (_slotError != null)
                TextButton(
                  onPressed: () => _loadSlots(_selectedDay!),
                  child: const Text('Không thể tải khung giờ. Thử lại'),
                )
              else if (_slots.isEmpty)
                const Text('Không còn khung giờ trống trong ngày này.')
              else
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: _slots
                      .map(
                        (slot) => ChoiceChip(
                          label: Text(
                            '${slot.label} - ${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}',
                          ),
                          selected: _time == slot.label,
                          onSelected: slot.isAvailable
                              ? (_) => setState(() => _time = slot.label)
                              : null,
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 26),
              TextFormField(
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Lý do khám',
                  hintText: 'Nhập triệu chứng hoặc lý do bạn muốn khám...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _submitting ? 'Đang đặt lịch...' : 'Xác nhận đặt lịch',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor, required this.onTap});
  final Doctor doctor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Ink(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: doctor.color,
            child: const Icon(Icons.person, color: AppColors.navy),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  doctor.specialty,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  doctor.experience,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.mutedText),
        ],
      ),
    ),
  );
}

class _DoctorEmpty extends StatelessWidget {
  const _DoctorEmpty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Không tìm thấy bác sĩ phù hợp.',
      style: TextStyle(color: AppColors.mutedText),
    ),
  );
}
