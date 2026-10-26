import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../notifications/data/notification_store.dart';
import '../../notifications/domain/notification_item.dart';

class DoctorRatingDialog extends StatefulWidget {
  const DoctorRatingDialog({
    super.key,
    required this.appointment,
    required this.repository,
  });

  final Appointment appointment;
  final AppointmentRepository repository;

  static Future<Appointment?> show(
    BuildContext context, {
    required Appointment appointment,
    required AppointmentRepository repository,
  }) {
    return showModalBottomSheet<Appointment>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DoctorRatingDialog(
        appointment: appointment,
        repository: repository,
      ),
    );
  }

  @override
  State<DoctorRatingDialog> createState() => _DoctorRatingDialogState();
}

class _DoctorRatingDialogState extends State<DoctorRatingDialog> {
  int _selectedRating = 5;
  final TextEditingController _reviewController = TextEditingController();
  bool _submitting = false;

  final List<String> _ratingLabels = [
    'Rất không hài lòng',
    'Chưa hài lòng',
    'Bình thường',
    'Hài lòng',
    'Tuyệt vời & Rất tận tâm!',
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final updated = await widget.repository.rateAppointment(
        widget.appointment.id,
        rating: _selectedRating,
        reviewNote: _reviewController.text.trim(),
      );

      NotificationStore.instance.addNotification(
        title: 'Đã gửi đánh giá thành công',
        body: 'Cảm ơn bạn đã gửi đánh giá $_selectedRating sao cho ${widget.appointment.doctorName}.',
        type: NotificationType.system,
      );

      if (mounted) {
        Navigator.pop(context, updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cảm ơn bạn đã đánh giá bác sĩ!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể gửi đánh giá. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Đánh giá buổi khám',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Buổi khám của bạn với ${widget.appointment.doctorName} như thế nào?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(
                Icons.medical_services_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.appointment.doctorName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.appointment.department,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final isSelected = starValue <= _selectedRating;
                return IconButton(
                  iconSize: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  icon: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected ? Colors.amber : Colors.grey.shade400,
                  ),
                  onPressed: () => setState(() => _selectedRating = starValue),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              _ratingLabels[_selectedRating - 1],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Nhập cảm nhận của bạn về sự tận tâm, chuyên môn của bác sĩ (tùy chọn)...',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submitRating,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Gửi đánh giá',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
