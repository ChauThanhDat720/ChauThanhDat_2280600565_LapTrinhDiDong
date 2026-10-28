import 'dart:async';
import '../../../core/realtime/hospital_realtime_service.dart';
import '../../../core/realtime/realtime_events.dart';
import '../../../core/repositories/application_backend.dart';

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../../core/theme/app_theme.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment.dart';
import '../domain/hospital_navigation.dart';
import '../../clinical_intake/data/clinical_intake_repository.dart';
import '../../clinical_intake/presentation/pre_visit_intake_screen.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/invoice.dart';
import '../../payments/presentation/vietqr_payment_screen.dart';

class DigitalBoardingPassScreen extends StatefulWidget {
  const DigitalBoardingPassScreen({
    super.key,
    required this.appointment,
    this.requirePayment = false,
    AppointmentRepository? repository,
  }) : _providedRepository = repository;

  final Appointment appointment;
  final bool requirePayment;
  final AppointmentRepository? _providedRepository;
  AppointmentRepository get repository =>
      _providedRepository ?? ApplicationBackend.repositories.appointments;

  @override
  State<DigitalBoardingPassScreen> createState() =>
      _DigitalBoardingPassScreenState();
}

class _DigitalBoardingPassScreenState extends State<DigitalBoardingPassScreen> {
  late Appointment _appointment;
  bool _checkingIn = false;
  bool _bookingPaid = true;
  Invoice? _bookingInvoice;
  StreamSubscription? _queueSub;
  bool _isCalledIn = false;
  int? _currentServingNumber;
  int _waitingAhead = 0;

  void _calculateQueuePosition() {
    final checkedInAll = AppointmentStore.instance.appointments
        .where((a) => a.doctorId == _appointment.doctorId && a.status == AppointmentStatus.checkedIn && a.queueNumber != null)
        .toList()
      ..sort((a, b) => a.queueNumber!.compareTo(b.queueNumber!));
    final myQueue = _appointment.queueNumber ?? 1;
    final ahead = checkedInAll.where((a) => a.queueNumber! < myQueue).length;
    final inProg = AppointmentStore.instance.appointments
        .where((a) => a.doctorId == _appointment.doctorId && a.status == AppointmentStatus.inProgress && a.queueNumber != null)
        .firstOrNull;
    if (mounted) {
      setState(() {
        _waitingAhead = ahead;
        _currentServingNumber = inProg?.queueNumber;
        if (_appointment.status == AppointmentStatus.inProgress) {
          _isCalledIn = true;
        }
      });
    }
  }

  bool get _enforcePayment =>
      widget.requirePayment ||
      widget.repository is LocalAppointmentRepository ||
      widget.repository is RemoteAppointmentRepository;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
    if (_enforcePayment) {
      _bookingPaid = _appointment.status == AppointmentStatus.checkedIn;
      _loadBookingPaymentStatus();
    }
    _queueSub = HospitalRealtimeService.instance.queueStream.listen((event) {
      if (event.appointmentId == _appointment.id) {
        if (event.type == RealtimeEventType.queueCalled || event.status == AppointmentStatus.inProgress) {
          if (mounted) {
            setState(() {
              _appointment = _appointment.copyWith(status: AppointmentStatus.inProgress);
              _isCalledIn = true;
            });
          }
        }
      }
      _calculateQueuePosition();
    });
    AppointmentStore.instance.addListener(_calculateQueuePosition);
    _calculateQueuePosition();
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    AppointmentStore.instance.removeListener(_calculateQueuePosition);
    super.dispose();
  }

  Future<void> _loadBookingPaymentStatus() async {
    final repo = LocalPaymentRepository();
    final inv = await repo.getOrCreateBookingInvoice(_appointment.id);
    final paid =
        _appointment.status == AppointmentStatus.checkedIn ||
        await repo.isStagePaid(_appointment.id, PaymentStage.booking);
    if (mounted) {
      setState(() {
        _bookingInvoice = inv;
        _bookingPaid = paid;
      });
    }
  }

  Future<void> _payBookingFee() async {
    final repo = LocalPaymentRepository();
    final inv =
        _bookingInvoice ??
        await repo.getOrCreateBookingInvoice(_appointment.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VietQrPaymentScreen(invoice: inv, repository: repo),
      ),
    );
    await _loadBookingPaymentStatus();
  }

  Future<void> _checkIn() async {
    setState(() => _checkingIn = true);
    try {
      final updated = await widget.repository.checkinAppointment(
        _appointment.id,
      );
      HospitalRealtimeService.instance.notifyPatientCheckin(
        appointmentId: updated.id,
        doctorId: updated.doctorId,
        doctorName: updated.doctorName,
        patientName: updated.patientName,
        queueNumber: updated.queueNumber ?? 1,
        roomNumber: updated.roomNumber ?? 'Phòng 204',
      );
      if (mounted) {
        setState(() {
          _appointment = updated;
          _checkingIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Tiếp đón thành công! Số thứ tự của bạn là: ${_appointment.queueNumber ?? 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Không thể tiếp đón: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = _appointment.status == AppointmentStatus.checkedIn;
    final checkinCode = 'CHECKIN:${_appointment.id}';
    final route = HospitalNavigationResolver.resolveRoute(_appointment);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thẻ Tiếp đón Phòng khám'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // Digital Boarding Pass Ticket Container
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // Header of Boarding Pass
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isCheckedIn
                                ? [
                                    const Color(0xFF0D9488),
                                    const Color(0xFF059669),
                                  ]
                                : [AppColors.primary, const Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_hospital_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SMART HOSPITAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    isCheckedIn
                                        ? 'PHIẾU ĐÃ TIẾP ĐÓN - CHỜ KHÁM'
                                        : 'THẺ TIẾP ĐÓN PHÒNG KHÁM',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
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
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isCheckedIn ? 'Đã có mặt' : 'Chờ tiếp đón',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content Body
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Queue Number Callout (if checked in)
                            if (isCheckedIn) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF0D9488)
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'SỐ THỨ TỰ KHÁM CỦA BẠN',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D9488),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'STT: ${_appointment.queueNumber?.toString().padLeft(2, '0') ?? '01'}',
                                      style: const TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F766E),
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _appointment.roomNumber ??
                                          route.clinicRoom,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Vui lòng theo dõi màn hình hiển thị phòng chờ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],

                            // Patient & Doctor Information Rows
                            _infoRow(
                              'Bệnh nhân:',
                              _appointment.patientName,
                              isBold: true,
                            ),
                            const SizedBox(height: 10),
                            _infoRow('Mã ca khám:', _appointment.id),
                            const SizedBox(height: 10),
                            _infoRow(
                              'Bác sĩ phụ trách:',
                              _appointment.doctorName,
                              isBold: true,
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              'Khoa khám:',
                              '${_appointment.department} - ${_appointment.specialty}',
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              'Thời gian hẹn:',
                              '${_appointment.dateLabel} lúc ${_appointment.time}',
                            ),
                            const SizedBox(height: 10),
                            ListenableBuilder(
                              listenable: ClinicalIntakeStore.instance,
                              builder: (context, _) {
                                final intake = ClinicalIntakeStore.instance
                                    .getByAppointmentId(_appointment.id);
                                return InkWell(
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PreVisitIntakeScreen(
                                          appointment: _appointment,
                                          repository:
                                              widget.repository
                                                  is RemoteAppointmentRepository
                                              ? ApplicationBackend
                                                    .repositories
                                                    .clinicalIntake
                                              : const LocalClinicalIntakeRepository(),
                                        ),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: intake != null
                                          ? const Color(0xFFF0FDF4)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: intake != null
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFFFCD34D),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          intake != null
                                              ? Icons
                                                    .assignment_turned_in_rounded
                                              : Icons.edit_note_rounded,
                                          size: 16,
                                          color: intake != null
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            intake != null
                                                ? 'Triệu chứng tiền khám: Đã nộp (VAS ${intake.painLevel}/10, ${intake.painLocation})'
                                                : 'Chưa khai báo triệu chứng tiền khám (Nhấn để điền)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: intake != null
                                                  ? const Color(0xFF166534)
                                                  : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16,
                                          color: intake != null
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFD97706),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // Ticket Divider with Dashes
                            Row(
                              children: List.generate(
                                30,
                                (_) => Expanded(
                                  child: Container(
                                    height: 1.5,
                                    color: Colors.grey.shade300,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // QR Code Section (Gated on Stage 1 Booking Fee Payment)
                            if (_bookingPaid) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: _QrCanvasView(
                                  data: checkinCode,
                                  size: 160,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                checkinCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: AppColors.mutedText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isCheckedIn
                                    ? 'Mã QR đã được xác thực tiếp đón thành công'
                                    : 'Đưa mã QR này cho nhân viên tiếp đón tại cửa phòng khám',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCheckedIn
                                      ? const Color(0xFF0D9488)
                                      : AppColors.mutedText,
                                  fontWeight: isCheckedIn
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.lock_clock_rounded,
                                      size: 46,
                                      color: Color(0xFFD97706),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '🔒 CHƯA CẤP MÃ QR CHECK-IN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Vui lòng hoàn tất thanh toán Phí đăng ký khám chuyên khoa (150.000 đ) để nhận Mã QR Check-in và lấy Số thứ tự (STT) vào phòng khám.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF78350F),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action simulation button
                if (!isCheckedIn) ...[
                  if (!_bookingPaid) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFFD97706),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text(
                        'Thanh toán Phí đăng ký khám (150.000 đ) để nhận QR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _payBookingFee,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sau khi thanh toán thành công, Mã QR Check-in sẽ được mở khóa tự động.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFF0D9488),
                      ),
                      icon: _checkingIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(
                        _checkingIn
                            ? 'Đang tiếp đón...'
                            : 'Mô phỏng Quét Check-in Ngay',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _checkingIn ? null : _checkIn,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nhấn để mô phỏng quét mã QR tại quầy tiếp đón phòng khám.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 20),

                // Smart Indoor Hospital Navigation Section
                _buildNavigationSection(route),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.mutedText),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationSection(HospitalRoute route) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Color(0xFF0D9488),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LỘ TRÌNH CHỈ ĐƯỜNG THÔNG MINH',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Lộ trình linh hoạt theo phòng khám của ${route.doctorName}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '~${route.estimatedWalkingMinutes}p đi bộ',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Overview banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF475569),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đích đến khám: ${route.clinicRoom} (${route.buildingWing} - ${route.floor})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step by step list
          ...route.steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final isLast = idx == route.steps.length - 1;
            return _buildNavigationStepItem(step, isLast: isLast);
          }),

          const SizedBox(height: 14),
          // Interactive Hospital Map Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9488),
                side: const BorderSide(color: Color(0xFF0D9488)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text(
                'Xem Sơ đồ Toà nhà & Mặt bằng Bệnh viện',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => _showHospitalFloorMapModal(context, route),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationStepItem(NavigationStep step, {required bool isLast}) {
    final statusColor = step.isDone
        ? const Color(0xFF16A34A)
        : (step.isCurrent ? const Color(0xFF0D9488) : const Color(0xFF94A3B8));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor,
                  width: step.isCurrent ? 2 : 1.5,
                ),
              ),
              child: Icon(
                step.isDone ? Icons.check_circle_rounded : step.icon,
                color: statusColor,
                size: 18,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 52,
                color: step.isDone
                    ? const Color(0xFF16A34A)
                    : Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'BƯỚC ${step.stepNumber}:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (step.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          step.badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${step.locationName} • [${step.buildingWing} - ${step.floor}]',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.directions,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showHospitalFloorMapModal(BuildContext context, HospitalRoute route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HospitalFloorMapSheet(route: route),
    );
  }
}

class _QrCanvasView extends StatelessWidget {
  const _QrCanvasView({required this.data, this.size = 160});
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);

    return CustomPaint(
      size: Size(size, size),
      painter: _QrCanvasPainter(qrImage),
    );
  }
}

class _QrCanvasPainter extends CustomPainter {
  _QrCanvasPainter(this.image);
  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0F172A);
    final squareSize = size.width / image.moduleCount;

    for (var x = 0; x < image.moduleCount; x++) {
      for (var y = 0; y < image.moduleCount; y++) {
        if (image.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * squareSize,
              y * squareSize,
              squareSize,
              squareSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HospitalFloorMapSheet extends StatefulWidget {
  const _HospitalFloorMapSheet({required this.route});
  final HospitalRoute route;

  @override
  State<_HospitalFloorMapSheet> createState() => _HospitalFloorMapSheetState();
}

class _HospitalFloorMapSheetState extends State<_HospitalFloorMapSheet> {
  late int _selectedFloorLevel;
  final List<HospitalFloorPlan> _plans =
      HospitalNavigationResolver.getFloorPlans();

  @override
  void initState() {
    super.initState();
    // Default to the floor of the doctor's room
    if (widget.route.floor.contains('1')) {
      _selectedFloorLevel = 1;
    } else if (widget.route.floor.contains('3')) {
      _selectedFloorLevel = 3;
    } else if (widget.route.floor.contains('trệt')) {
      _selectedFloorLevel = 0;
    } else {
      _selectedFloorLevel = 2; // Default to 2nd floor
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = _plans.firstWhere(
      (p) => p.floorLevel == _selectedFloorLevel,
      orElse: () => _plans[1],
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.map_rounded,
                  color: Color(0xFF0D9488),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SƠ ĐỒ MẶT BẰNG BỆNH VIỆN',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Định vị phòng khám & các khoa phòng theo thời gian thực',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedText,
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
          const Divider(height: 16),

          // Floor selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _plans.map((plan) {
                final isSelected = plan.floorLevel == _selectedFloorLevel;
                final isDoctorFloor =
                    (widget.route.floor.contains('1') &&
                        plan.floorLevel == 1) ||
                    (widget.route.floor.contains('2') &&
                        plan.floorLevel == 2) ||
                    (widget.route.floor.contains('3') &&
                        plan.floorLevel == 3) ||
                    (widget.route.floor.contains('trệt') &&
                        plan.floorLevel == 0);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: isDoctorFloor
                        ? const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          )
                        : null,
                    label: Text(
                      plan.floorName.split(' (').first,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D9488)
                        .withValues(alpha: 0.18),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedFloorLevel = plan.floorLevel);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Floor info & description
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.layers_outlined,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentPlan.description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Wings & Rooms Map View
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                ...currentPlan.wings.map((wing) => _buildWingCard(wing)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWingCard(HospitalWingPlan wing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D9488),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                wing.wingName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 14),
          ...wing.rooms.map((room) {
            final isDoctorRoom =
                room.doctorId == widget.route.doctorId ||
                widget.route.clinicRoom.contains(room.roomCode);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDoctorRoom
                    ? const Color(0xFFCCFBF1)
                    : (room.category == 'lab'
                          ? const Color(0xFFF0FDF4)
                          : (room.category == 'pharmacy'
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFF8FAFC))),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDoctorRoom
                      ? const Color(0xFF0D9488)
                      : Colors.grey.shade200,
                  width: isDoctorRoom ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    room.category == 'pharmacy'
                        ? Icons.local_pharmacy_rounded
                        : (room.category == 'lab'
                              ? Icons.science_outlined
                              : (room.category == 'reception'
                                    ? Icons.support_agent_rounded
                                    : Icons.meeting_room_rounded)),
                    size: 20,
                    color: isDoctorRoom
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              room.roomCode,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: isDoctorRoom
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            if (isDoctorRoom) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ĐÍCH ĐẾN CỦA BẠN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          room.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isDoctorRoom
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isDoctorRoom
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
