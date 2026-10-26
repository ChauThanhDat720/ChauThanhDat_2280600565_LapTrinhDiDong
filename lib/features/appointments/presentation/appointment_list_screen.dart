import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../../doctors/domain/doctor.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment.dart';
import '../../medical_records/presentation/doctor_rating_dialog.dart';
import '../../medical_records/presentation/medical_record_pdf_preview_screen.dart';
import '../../medical_records/presentation/lab_results_detail_screen.dart';
import 'digital_boarding_pass_screen.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/vietqr_payment_screen.dart';
import '../../payments/presentation/e_invoice_screen.dart';
import '../../reminders/data/medication_reminder_repository.dart';
import '../../reminders/presentation/medication_reminder_screen.dart';
import '../../teleconsultation/presentation/post_care_chat_screen.dart';
import '../../clinical_intake/data/clinical_intake_repository.dart';
import '../../clinical_intake/presentation/pre_visit_intake_screen.dart';
import '../../clinical_intake/presentation/widgets/intake_summary_card.dart';

class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({
    super.key,
    this.showAppBar = true,
    this.repository = const LocalAppointmentRepository(),
  });
  final bool showAppBar;
  final AppointmentRepository repository;
  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  List<Appointment>? _items;
  Object? _error;
  bool _loading = true;
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
      final value = await widget.repository.getMyAppointments();
      if (mounted) setState(() => _items = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    return widget.showAppBar
        ? Scaffold(
            appBar: AppBar(title: const Text('Lịch khám của tôi')),
            body: body,
          )
        : body;
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang tải lịch khám...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không thể tải lịch khám.'),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final items = _items!;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text('Bạn chưa có lịch khám nào.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DoctorListScreen()),
              ),
              child: const Text('Đặt lịch khám'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              children: [
                
                const Spacer(),
                Text('${items.length} lịch khám'),
              ],
            );
          }
          final appointment = items[index - 1];
          return _AppointmentCard(
            appointment: appointment,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailScreen(
                    appointment: appointment,
                    repository: widget.repository,
                  ),
                ),
              );
              if (mounted) _load();
            },
          );
        },
      ),
    );
  }
}

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    required this.repository,
  });
  final Appointment appointment;
  final AppointmentRepository repository;
  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Appointment _appointment = widget.appointment;
  bool _cancelling = false;
  bool get _canCancel =>
      _appointment.status == AppointmentStatus.pending ||
      _appointment.status == AppointmentStatus.confirmed;
  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch khám'),
        content: const Text('Bạn có chắc chắn muốn hủy lịch khám này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (ok != true || _cancelling) return;
    setState(() => _cancelling = true);
    try {
      final updated = await widget.repository.cancelAppointment(
        _appointment.id,
      );
      if (mounted) {
        setState(() => _appointment = updated);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã hủy lịch khám.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể hủy lịch khám.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết lịch khám')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Mã lịch: ${_appointment.id}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        _line('Bác sĩ', _appointment.doctorName),
        _line('Khoa khám', _appointment.department),
        _line('Ngày khám', AppTimezone.date(_appointment.date)),
        _line(
          'Giờ khám',
          AppTimezone.range(_appointment.startTime, _appointment.endTime),
        ),
        _line('Lý do khám', _appointment.reason),
        _line('Trạng thái', _appointment.status.label),
        if (_appointment.createdAt != null)
          _line(
            'Tạo lúc',
            '${AppTimezone.date(_appointment.createdAt!)} ${AppTimezone.time(_appointment.createdAt!)}',
          ),
        if (_appointment.cancelledAt != null)
          _line(
            'Hủy lúc',
            '${AppTimezone.date(_appointment.cancelledAt!)} ${AppTimezone.time(_appointment.cancelledAt!)}',
          ),
        if (_appointment.cancellationReason?.isNotEmpty == true)
          _line('Lý do hủy', _appointment.cancellationReason!),
        // Pre-visit Clinical Intake Section
        if (_appointment.status != AppointmentStatus.cancelled) ...[
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: ClinicalIntakeStore.instance,
            builder: (context, _) {
              final intake = ClinicalIntakeStore.instance.getByAppointmentId(_appointment.id);
              if (intake != null) {
                return IntakeSummaryCard(
                  intake: intake,
                  onTapEdit: _appointment.status != AppointmentStatus.completed
                      ? () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PreVisitIntakeScreen(
                                appointment: _appointment,
                                repository: widget.repository is RemoteAppointmentRepository
                                    ? const RemoteClinicalIntakeRepository()
                                    : const LocalClinicalIntakeRepository(),
                              ),
                            ),
                          );
                          setState(() {});
                        }
                      : null,
                );
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_outlined, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Khai báo triệu chứng trước khám',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '⏱ 2 phút',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Điền trước thông tin vị trí đau, mức độ khó chịu (thang điểm 1-10) và thuốc đang dùng để Bác sĩ chuẩn bị chu đáo hơn.',
                      style: TextStyle(color: Color(0xFF134E4A), fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text('Điền phiếu triệu chứng tiền khám'),
                        onPressed: () async {
                          final res = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PreVisitIntakeScreen(
                                appointment: _appointment,
                                repository: widget.repository is RemoteAppointmentRepository
                                    ? const RemoteClinicalIntakeRepository()
                                    : const LocalClinicalIntakeRepository(),
                              ),
                            ),
                          );
                          if (res != null && mounted) {
                            setState(() {
                              _appointment = _appointment.copyWith(hasIntake: true);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
                if (_appointment.status == AppointmentStatus.completed &&
            ((_appointment.diagnosis != null && _appointment.diagnosis!.isNotEmpty) ||
                (_appointment.prescription != null &&
                    _appointment.prescription!.isNotEmpty))) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_information, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      'Kết quả khám bệnh & Đơn thuốc',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (_appointment.diagnosis != null &&
                    _appointment.diagnosis!.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text(
                    'Chẩn đoán của bác sĩ:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(_appointment.diagnosis!,
                      style: const TextStyle(fontSize: 14)),
                ],
                if (_appointment.prescription != null &&
                    _appointment.prescription!.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text(
                    'Đơn thuốc & Hướng dẫn sử dụng:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(_appointment.prescription!,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.alarm_add_rounded, size: 18),
                    label: const Text('Tạo lịch nhắc uống thuốc từ toa này'),
                    onPressed: () async {
                      try {
                        const reminderRepo = RemoteMedicationReminderRepository();
                        await reminderRepo.createFromPrescription(
                          prescription: _appointment.prescription!,
                          appointmentId: _appointment.id,
                          patientId: _appointment.patientId,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã tạo lịch nhắc uống thuốc thành công từ đơn thuốc!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MedicationReminderScreen(),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi tạo lịch nhắc: $e')),
                        );
                      }
                    },
                  ),
                ],
                if (_appointment.statusNote != null &&
                    _appointment.statusNote!.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text(
                    'Lời dặn của bác sĩ:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _appointment.statusNote!,
                    style: const TextStyle(
                        fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
                if (_appointment.status == AppointmentStatus.completed &&
            _appointment.followUpDate != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_repeat_rounded, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hẹn tái khám: ${_appointment.followUpDateLabel}',
                        style: const TextStyle(
                          color: Color(0xFF1E40AF),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bác sĩ ${_appointment.doctorName} chỉ định bạn tái khám vào ngày ${_appointment.followUpDateLabel}. Hãy chọn khung giờ thích hợp để được ưu tiên khám đúng hẹn!',
                  style: const TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('Đặt lịch tái khám ngay theo hẹn'),
                    onPressed: () {
                      final doc = doctors.firstWhere(
                        (d) => d.id == _appointment.doctorId,
                        orElse: () => Doctor(
                          id: _appointment.doctorId,
                          name: _appointment.doctorName,
                          departmentId: 'general',
                          department: _appointment.department,
                          specialty: _appointment.department,
                          experience: 'Bác sĩ chuyên khoa',
                          color: const Color(0xFFBDE5E9),
                        ),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookAppointmentScreen(
                            doctor: doc,
                            initialDate: _appointment.followUpDate,
                            initialReason:
                                'Tái khám theo hẹn: ${_appointment.diagnosis ?? "Kiểm tra định kỳ"}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_appointment.status == AppointmentStatus.completed) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kênh Tư vấn Y tế Hậu khám (7 ngày)',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '🟢 7 ngày hỗ trợ',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn có thắc mắc về liều dùng, tác dụng phụ của thuốc hoặc triệu chứng sau khám? Hãy nhắn tin trao đổi trực tiếp với ${_appointment.doctorName}.',
                  style: const TextStyle(color: Color(0xFF134E4A), fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: Text('Nhắn tin với ${_appointment.doctorName}'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostCareChatScreen(
                            appointmentId: _appointment.id,
                            currentUserId: _appointment.patientId,
                            currentUserName: _appointment.patientName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Xuất phiếu khám & Đơn thuốc (PDF)'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MedicalRecordPdfPreviewScreen(appointment: _appointment),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE0F2FE),
              foregroundColor: const Color(0xFF0369A1),
            ),
            icon: const Icon(Icons.biotech_rounded, size: 20, color: Color(0xFF0284C7)),
            label: const Text('Xem Kết quả Xét nghiệm & CĐHA'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LabResultsDetailScreen(appointment: _appointment),
                ),
              );
            },
          ),
          if (_appointment.followUpDate != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.bolt_rounded, size: 20),
              label: Text(
                '1 chạm Đặt lịch tái khám (${_appointment.followUpDateLabel})',
              ),
              onPressed: () {
                final doc = doctors
                        .where((d) => d.id == _appointment.doctorId)
                        .firstOrNull ??
                    Doctor(
                      id: _appointment.doctorId,
                      name: _appointment.doctorName,
                      departmentId: _appointment.departmentId,
                      department: _appointment.department,
                      specialty: _appointment.specialty,
                      experience: 'Bác sĩ chuyên khoa',
                      color: const Color(0xFFBDE5E9),
                    );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookAppointmentScreen(
                      doctor: doc,
                      initialDate: _appointment.followUpDate,
                      initialReason:
                          'Tái khám theo chỉ định của ${_appointment.doctorName} (Đợt khám ${_appointment.dateLabel})',
                      isFollowUp: true,
                      parentAppointmentId: _appointment.id,
                      repository: widget.repository,
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          if (_appointment.rating != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Row(
                    children: List.generate(5, (idx) {
                      return Icon(
                        idx < _appointment.rating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 22,
                      );
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _appointment.reviewNote?.isNotEmpty == true
                          ? '"${_appointment.reviewNote}"'
                          : 'Đã đánh giá ${_appointment.rating} sao',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.star_outline_rounded, color: Colors.amber),
              label: const Text('Đánh giá bác sĩ'),
              onPressed: () async {
                final updated = await DoctorRatingDialog.show(
                  context,
                  appointment: _appointment,
                  repository: widget.repository,
                );
                if (updated != null && mounted) {
                  setState(() => _appointment = updated);
                }
              },
            ),
          ],
        ],
        if (_appointment.status != AppointmentStatus.cancelled &&
            _appointment.status != AppointmentStatus.completed) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: Text(
              _appointment.status == AppointmentStatus.checkedIn
                  ? 'Thẻ lên phòng khám (STT: ${_appointment.queueNumber?.toString().padLeft(2, '0') ?? '01'})'
                  : 'Thẻ lên phòng khám và QR Check-in',
            ),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DigitalBoardingPassScreen(
                    appointment: _appointment,
                    repository: widget.repository,
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
          icon: const Icon(Icons.payments_rounded),
          label: const Text('Thanh toán viện phí & Hóa đơn VietQR'),
          onPressed: () async {
            final nav = Navigator.of(context);
            final paymentRepo = LocalPaymentRepository();
            final invoice = await paymentRepo.getInvoiceForAppointment(_appointment.id);
            if (invoice.isPaid) {
              nav.push(
                MaterialPageRoute(
                  builder: (_) => EInvoiceScreen(invoice: invoice),
                ),
              );
            } else {
              nav.push(
                MaterialPageRoute(
                  builder: (_) => VietQrPaymentScreen(
                    invoice: invoice,
                    repository: paymentRepo,
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 24),
        if (_canCancel)
          ElevatedButton.icon(
            onPressed: _cancelling ? null : _cancel,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(_cancelling ? 'Đang hủy...' : 'Hủy lịch khám'),
          ),
      ],
    ),
  );
  Widget _line(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value.isEmpty ? 'Chưa cập nhật' : value),
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onTap});
  final Appointment appointment;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(appointment.doctorName),
      subtitle: Text(
        '${appointment.department}\n${appointment.dateLabel} • ${appointment.time}\nMã lịch: ${appointment.id}',
      ),
      isThreeLine: true,
      trailing: Chip(label: Text(appointment.status.label)),
    ),
  );
}
