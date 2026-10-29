import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/invoice.dart';
import '../../payments/presentation/vietqr_payment_screen.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment.dart';
import 'appointment_list_screen.dart';
import 'digital_boarding_pass_screen.dart';

class AppointmentSuccessScreen extends StatefulWidget {
  const AppointmentSuccessScreen({
    super.key,
    required this.appointment,
    required this.repository,
  });

  final Appointment appointment;
  final AppointmentRepository repository;

  @override
<<<<<<< HEAD
  State<AppointmentSuccessScreen> createState() =>
      _AppointmentSuccessScreenState();
}

class _AppointmentSuccessScreenState extends State<AppointmentSuccessScreen> {
  Invoice? _bookingInvoice;
  bool _isBookingPaid = false;

  @override
  void initState() {
    super.initState();
    _loadBookingInvoice();
  }

  Future<void> _loadBookingInvoice() async {
    final repo = LocalPaymentRepository();
    final inv = await repo.getOrCreateBookingInvoice(widget.appointment.id);
    final paid = await repo.isStagePaid(
      widget.appointment.id,
      PaymentStage.booking,
    );
    if (mounted) {
      setState(() {
        _bookingInvoice = inv;
        _isBookingPaid = paid;
      });
    }
  }

  Future<void> _payBookingFee() async {
    final repo = LocalPaymentRepository();
    final inv =
        _bookingInvoice ??
        await repo.getOrCreateBookingInvoice(widget.appointment.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VietQrPaymentScreen(invoice: inv, repository: repo),
      ),
    );
    await _loadBookingInvoice();
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lịch thành công')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  _isBookingPaid
                      ? Icons.check_circle
                      : Icons.pending_actions_rounded,
                  size: 76,
                  color: _isBookingPaid
                      ? AppColors.success
                      : const Color(0xFFD97706),
                ),
                const SizedBox(height: 16),
                Text(
                  _isBookingPaid
                      ? 'Đã xác nhận & Cấp Mã QR Check-in!'
                      : 'Đặt lịch khám thành công!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isBookingPaid
                      ? 'Bạn đã hoàn tất thanh toán Phí đăng ký khám. Mã QR Check-in phòng khám đã sẵn sàng.'
                      : 'Lịch khám của bạn đã được ghi nhận. Vui lòng thanh toán Phí đăng ký khám để nhận Mã QR Check-in.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isBookingPaid
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isBookingPaid
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
=======
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đặt lịch thành công')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                size: 76,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              Text(
                'Đặt lịch khám thành công!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                appointment.status == AppointmentStatus.pending
                    ? 'Yêu cầu đặt lịch đã được gửi. Vui lòng chờ bác sĩ xác nhận.'
                    : 'Lịch khám của bạn đã được ghi nhận.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
>>>>>>> 287bb2e (Fix bugs and update code)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isBookingPaid
                                ? Icons.verified_rounded
                                : Icons.lock_clock_rounded,
                            color: _isBookingPaid
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isBookingPaid
                                  ? 'Đã thanh toán Phí đăng ký khám (150.000 đ)'
                                  : 'Chờ thanh toán Phí đăng ký khám (150.000 đ)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isBookingPaid
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isBookingPaid
                            ? 'Mã QR Check-in phòng khám: CHECKIN:${appointment.id}'
                            : '🔒 Mã QR Check-in vào phòng khám chỉ được cấp sau khi bạn hoàn tất thanh toán Phí khám ban đầu.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _isBookingPaid
                              ? const Color(0xFF15803D)
                              : const Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _line('Mã lịch khám', appointment.id),
                        _line('Bác sĩ', appointment.doctorName),
                        _line('Khoa khám', appointment.department),
                        _line('Ngày khám', AppTimezone.date(appointment.date)),
                        _line(
                          'Giờ khám',
                          AppTimezone.range(
                            appointment.startTime,
                            appointment.endTime,
                          ),
                        ),
                        _line('Trạng thái', appointment.status.label),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (!_isBookingPaid) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text(
                        'Thanh toán Phí khám ngay (150.000 đ) để nhận QR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _payBookingFee,
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text(
                        'Mở Thẻ Lên Phòng Khám & Mã QR Check-in',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => DigitalBoardingPassScreen(
                            appointment: appointment,
                            repository: widget.repository,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => AppointmentListScreen(
                          repository: widget.repository,
                        ),
                      ),
                      (route) => route.isFirst,
                    ),
                    child: const Text('Xem lịch khám'),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Về trang chủ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}
