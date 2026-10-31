import 'dart:async';
import '../../../core/realtime/hospital_realtime_service.dart';
import '../../../core/repositories/application_backend.dart';
import '../../../core/session/patient_session.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/invoice.dart';
import '../../payments/presentation/vietqr_payment_screen.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment.dart';
import 'digital_boarding_pass_screen.dart';

class ReceptionCheckinScreen extends StatefulWidget {
  const ReceptionCheckinScreen({super.key, AppointmentRepository? repository})
    : _providedRepository = repository;

  final AppointmentRepository? _providedRepository;
  AppointmentRepository get repository =>
      _providedRepository ?? ApplicationBackend.repositories.appointments;

  @override
  State<ReceptionCheckinScreen> createState() => _ReceptionCheckinScreenState();
}

class _ReceptionCheckinScreenState extends State<ReceptionCheckinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  List<Appointment> _appointments = [];
  bool _loading = true;
  bool _processing = false;
  StreamSubscription? _queueSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAppointments();
    AppointmentStore.instance.addListener(_loadAppointments);
    _queueSub = HospitalRealtimeService.instance.queueStream.listen((_) {
      if (mounted) _loadAppointments();
    });
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => _loading = true);
    try {
      final list = PatientSession.instance.role == 'doctor'
          ? await widget.repository.getDoctorAppointments()
          : await widget.repository.getAppointments();
      if (mounted) {
        setState(() {
          _appointments = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _processCheckin(String rawCode) async {
    if (_processing || rawCode.trim().isEmpty) return;
    final cleanId = rawCode
        .trim()
        .replaceFirst(RegExp(r'^CHECKIN:', caseSensitive: false), '')
        .trim();

    if (widget.repository is LocalAppointmentRepository ||
        widget.repository is RemoteAppointmentRepository) {
      final paymentRepo = LocalPaymentRepository();
      final bookingPaid = await paymentRepo.isStagePaid(
        cleanId,
        PaymentStage.booking,
      );
      if (!bookingPaid && mounted) {
        final inv = await paymentRepo.getOrCreateBookingInvoice(cleanId);
        if (!mounted) return;
        final payNow = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFFD97706),
              size: 48,
            ),
            title: const Text('Chưa thanh toán Phí đăng ký khám'),
            content: const Text(
              'Bệnh nhân cần hoàn tất thanh toán Phí đăng ký khám chuyên khoa (150.000 đ) trước khi được cấp Mã QR Check-in và lấy Số thứ tự (STT) vào phòng khám.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Đóng'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                ),
                icon: const Icon(Icons.qr_code_rounded, size: 18),
                label: const Text('Thanh toán Phí khám ngay'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
        if (payNow == true && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  VietQrPaymentScreen(invoice: inv, repository: paymentRepo),
            ),
          );
        }
        return;
      }
    }

    setState(() => _processing = true);
    try {
      final updated = await widget.repository.checkinAppointment(cleanId);
      await _loadAppointments();

      if (mounted) {
        setState(() => _processing = false);
        _codeController.clear();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 52,
            ),
            title: const Text('Tiếp đón thành công!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bệnh nhân: ${updated.patientName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0D9488)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'SỐ THỨ TỰ KHÁM (STT)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                      Text(
                        updated.queueNumber?.toString().padLeft(2, '0') ?? '01',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                      Text(
                        updated.roomNumber ?? 'Phòng 204 - Tầng 2',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bác sĩ: ${updated.doctorName} (${updated.department})',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DigitalBoardingPassScreen(
                        appointment: updated,
                        repository: widget.repository,
                      ),
                    ),
                  );
                },
                child: const Text('Xem Thẻ lên phòng khám'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Lỗi tiếp đón: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitingToConfirm = _appointments
        .where((a) => a.status == AppointmentStatus.confirmed)
        .toList();
    final checkedInQueue =
        _appointments
            .where((a) => a.status == AppointmentStatus.checkedIn)
            .toList()
          ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quầy Tiếp đón & Kiosk Check-in'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Tiếp đón bệnh nhân (${waitingToConfirm.length})',
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
            Tab(
              text: 'Hàng đợi phòng chờ (${checkedInQueue.length})',
              icon: const Icon(Icons.queue_play_next_rounded),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Reception Check-in form & ready list
          RefreshIndicator(
            onRefresh: _loadAppointments,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fast Code Input Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quét hoặc nhập mã lịch hẹn (APT-XXXX)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Quét mã QR từ Thẻ lên phòng khám của bệnh nhân để tự động cấp số thứ tự.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Nhập mã ca khám hoặc CHECKIN:APT-...',
                                    prefixIcon: const Icon(
                                      Icons.qr_code_2_rounded,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onSubmitted: _processCheckin,
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: _processing
                                    ? null
                                    : () =>
                                          _processCheckin(_codeController.text),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                                child: _processing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Tiếp đón'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // List of Appointments Ready to Check-in
                  const Text(
                    'Ca khám sẵn sàng tiếp đón hôm nay',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (waitingToConfirm.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: AppColors.mutedText,
                            size: 36,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Không có ca khám nào đang chờ tiếp đón.',
                            style: TextStyle(color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: waitingToConfirm.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = waitingToConfirm[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              item.patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${item.doctorName} • ${item.time} (${item.dateLabel})\nMã: ${item.id}',
                            ),
                            isThreeLine: true,
                            trailing: FilledButton.tonalIcon(
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Tiếp đón'),
                              onPressed: () => _processCheckin(item.id),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Tab 2: Waiting Room Live Queue Monitor
          RefreshIndicator(
            onRefresh: _loadAppointments,
            child: checkedInQueue.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.airline_seat_recline_normal_rounded,
                          size: 64,
                          color: AppColors.mutedText,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có bệnh nhân nào trong phòng chờ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mutedText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Các ca khám đã tiếp đón sẽ hiển thị số thứ tự tại đây.',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: checkedInQueue.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = checkedInQueue[index];
                      final isCurrent = index == 0;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF0D9488).withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFF0D9488)
                                : Colors.grey.shade200,
                            width: isCurrent ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Large STT Badge
                            Container(
                              width: 60,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFF0D9488)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.queueNumber?.toString().padLeft(2, '0') ??
                                    '01',
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.white
                                      : AppColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.patientName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0D9488),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Đang gọi',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'BS: ${item.doctorName} • ${item.department}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                                  Text(
                                    item.roomNumber ?? 'Phòng 204 - Tầng 2',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0D9488),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Xem thẻ lên phòng khám',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DigitalBoardingPassScreen(
                                      appointment: item,
                                      repository: widget.repository,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
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
