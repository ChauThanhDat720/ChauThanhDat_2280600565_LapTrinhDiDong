import '../../../core/repositories/application_backend.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../tools/alarm/alarm_screen.dart';
import 'doctor_rating_dialog.dart';
import 'medical_record_pdf_preview_screen.dart';
import '../../medicines/data/medicine_repository.dart';
import '../../medicines/presentation/medicine_detail_screen.dart';
import '../../medicines/presentation/medicine_list_screen.dart';
import '../../reminders/data/medication_reminder_repository.dart';
import '../../reminders/presentation/medication_reminder_screen.dart';
import 'lab_results_detail_screen.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key, AppointmentRepository? repository})
    : _providedRepository = repository;

  final AppointmentRepository? _providedRepository;
  AppointmentRepository get repository =>
      _providedRepository ?? ApplicationBackend.repositories.appointments;

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  List<Appointment> _records = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() => _loading = true);
    try {
      final all = await widget.repository.getAppointments();
      final completed = all
          .where((item) => item.status == AppointmentStatus.completed)
          .toList();
      completed.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _records = completed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Appointment> get _filteredRecords {
    if (_searchQuery.trim().isEmpty) return _records;
    final q = _searchQuery.toLowerCase();
    return _records.where((item) {
      final doc = item.doctorName.toLowerCase();
      final diag = (item.diagnosis ?? '').toLowerCase();
      final pres = (item.prescription ?? '').toLowerCase();
      final dept = item.department.toLowerCase();
      return doc.contains(q) ||
          diag.contains(q) ||
          pres.contains(q) ||
          dept.contains(q);
    }).toList();
  }

  Future<void> _lookupMedicine(BuildContext context, String rawName) async {
    const medRepo = LocalMedicineRepository();
    final found = await medRepo.lookupByName(rawName);
    if (!context.mounted) return;
    if (found != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MedicineDetailScreen(medicine: found),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MedicineListScreen(initialSearch: rawName),
        ),
      );
    }
  }

  Future<void> _createRemindersFromPrescription(
    BuildContext context,
    Appointment item,
  ) async {
    if (item.prescription == null || item.prescription!.trim().isEmpty) return;
    try {
      const repo = RemoteMedicationReminderRepository();
      final reminders = await repo.createFromPrescription(
        prescription: item.prescription!,
        appointmentId: item.id,
        patientId: item.patientId.isNotEmpty ? item.patientId : 'patient-1',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0D9488),
          content: Text(
            'Đã tạo thành công ${reminders.length} lời nhắc uống thuốc!',
          ),
          action: SnackBarAction(
            label: 'Xem lịch',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MedicationReminderScreen(
                    repository: RemoteMedicationReminderRepository(),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Lỗi tạo lịch nhắc: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ khám & Đơn thuốc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'Từ điển thuốc',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MedicineListScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecords,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Tìm theo bệnh, thuốc hoặc bác sĩ...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: AppColors.mutedText.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Chưa có hồ sơ bệnh án nào'
                                : 'Không tìm thấy kết quả phù hợp',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Các ca khám đã hoàn thành sẽ được lưu trữ tại đây.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        return _buildRecordCard(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(Appointment item) {
    final hasPrescription =
        item.prescription != null && item.prescription!.isNotEmpty;
    final hasDiagnosis = item.diagnosis != null && item.diagnosis!.isNotEmpty;
    final isRated = item.rating != null && item.rating! > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.doctorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.department} • ${AppTimezone.date(item.date)}',
                      style: const TextStyle(
                        fontSize: 13,
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
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Đã khám xong',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (hasDiagnosis) ...[
            Row(
              children: const [
                Icon(
                  Icons.assignment_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Chẩn đoán của bác sĩ:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.diagnosis!,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (hasPrescription) ...[
            Row(
              children: [
                const Icon(
                  Icons.medication_outlined,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Đơn thuốc & Hướng dẫn:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Sao chép đơn thuốc',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.prescription!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép đơn thuốc vào bộ nhớ tạm.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                item.prescription!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final line
                    in item.prescription!
                        .split('\n')
                        .map((l) => l.trim())
                        .where((l) => l.isNotEmpty))
                  ActionChip(
                    avatar: const Icon(
                      Icons.menu_book_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Xem HDSD: ${line.length > 28 ? "${line.substring(0, 28)}..." : line}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                    onPressed: () => _lookupMedicine(context, line),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488)
                    .withValues(alpha: 0.12),
                foregroundColor: const Color(0xFF0D9488),
                minimumSize: const Size(double.infinity, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.alarm_add_rounded, size: 18),
              label: const Text(
                '1 chạm tạo Lịch nhắc uống thuốc',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => _createRemindersFromPrescription(context, item),
            ),
            const SizedBox(height: 14),
          ],
          if (item.statusNote != null && item.statusNote!.isNotEmpty) ...[
            Row(
              children: const [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 16,
                  color: Colors.orange,
                ),
                SizedBox(width: 6),
                Text(
                  'Lời dặn của bác sĩ:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.statusNote!,
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 14),
          ],

          // Rating section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isRated
                  ? Colors.amber.withValues(alpha: 0.08)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (isRated) ...[
                  Row(
                    children: List.generate(5, (starIdx) {
                      return Icon(
                        starIdx < item.rating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.reviewNote?.isNotEmpty == true
                          ? '"${item.reviewNote}"'
                          : 'Đã đánh giá ${item.rating} sao',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Bạn chưa đánh giá buổi khám này',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final updated = await DoctorRatingDialog.show(
                        context,
                        appointment: item,
                        repository: widget.repository,
                      );
                      if (updated != null) _loadRecords();
                    },
                    child: const Text('Đánh giá ngay'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Nút xem Kết quả Xét nghiệm & CĐHA
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE0F2FE),
                foregroundColor: const Color(0xFF0369A1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(
                Icons.biotech_rounded,
                size: 20,
                color: Color(0xFF0284C7),
              ),
              label: const Text(
                'Xem Kết quả Xét nghiệm & CĐHA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LabResultsDetailScreen(appointment: item),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text(
                    'Xuất phiếu & Đơn (PDF)',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MedicalRecordPdfPreviewScreen(appointment: item),
                      ),
                    );
                  },
                ),
              ),
              if (hasPrescription) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.alarm_add_rounded, size: 18),
                  label: const Text(
                    'Nhắc uống thuốc',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AlarmScreen()),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
