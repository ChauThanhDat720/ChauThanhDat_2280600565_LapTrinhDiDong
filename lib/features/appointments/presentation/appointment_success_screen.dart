import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment.dart';
import 'appointment_list_screen.dart';

class AppointmentSuccessScreen extends StatelessWidget {
  const AppointmentSuccessScreen({
    super.key,
    required this.appointment,
    required this.repository,
  });

  final Appointment appointment;
  final AppointmentRepository repository;

  @override
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
              const Text('Lịch khám của bạn đã được ghi nhận.'),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                          AppointmentListScreen(repository: repository),
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
