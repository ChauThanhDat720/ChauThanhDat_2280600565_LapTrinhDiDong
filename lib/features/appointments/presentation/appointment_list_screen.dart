import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../domain/appointment.dart';

class AppointmentListScreen extends StatelessWidget {
  const AppointmentListScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final body = _AppointmentListBody(showTitle: !showAppBar);
    if (!showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch khám của tôi')),
      body: body,
    );
  }
}

class _AppointmentListBody extends StatelessWidget {
  const _AppointmentListBody({required this.showTitle});

  final bool showTitle;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppointmentStore.instance,
    builder: (context, _) {
      final appointments = AppointmentStore.instance.getAppointments();
      if (appointments.isEmpty) {
        return _AppointmentEmptyState(showTitle: showTitle);
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        itemCount: appointments.length + (showTitle ? 1 : 0),
        separatorBuilder: (_, index) =>
            SizedBox(height: index == 0 && showTitle ? 18 : 12),
        itemBuilder: (context, index) {
          if (showTitle && index == 0) {
            return Text(
              'Lịch khám của tôi',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            );
          }
          final appointment = appointments[index - (showTitle ? 1 : 0)];
          return _AppointmentCard(appointment: appointment);
        },
      );
    },
  );
}

class _AppointmentEmptyState extends StatelessWidget {
  const _AppointmentEmptyState({required this.showTitle});

  final bool showTitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle) ...[
            Text(
              'Lịch khám của tôi',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 32),
          ],
          const Icon(
            Icons.calendar_month_outlined,
            size: 68,
            color: AppColors.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Bạn chưa có lịch khám',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy chọn bác sĩ và đặt lịch khám đầu tiên.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DoctorListScreen())),
            icon: const Icon(Icons.medical_services_outlined),
            label: const Text('Tìm bác sĩ'),
          ),
        ],
      ),
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final isCancelled = appointment.status == AppointmentStatus.cancelled;
    final statusColor = isCancelled
        ? Colors.red
        : appointment.status == AppointmentStatus.confirmed
        ? AppColors.success
        : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE4F4F5),
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.specialty,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.department,
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  AppointmentStatus.labelOf(appointment.status),
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
                backgroundColor: statusColor.withValues(alpha: .10),
                side: BorderSide.none,
              ),
            ],
          ),
          const Divider(height: 28),
          Text(
            '${appointment.dateLabel} • ${appointment.time}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text('Lý do:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            appointment.reason,
            style: const TextStyle(color: AppColors.mutedText),
          ),
          if (!isCancelled) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmCancellation(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Hủy lịch'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancellation(BuildContext context) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch khám'),
        content: const Text('Bạn có chắc muốn hủy lịch khám này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
    if (shouldCancel == true && context.mounted) {
      AppointmentStore.instance.cancelAppointment(appointment.id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã hủy lịch khám')));
    }
  }
}
