import '../../appointments/domain/appointment.dart';
import '../../payments/data/payment_repository.dart';
import 'package:flutter/material.dart';
import '../../../core/session/patient_session.dart';
import '../../../core/theme/app_theme.dart';
import '../data/medication_reminder_repository.dart';
import '../domain/medication_reminder.dart';
import 'add_edit_reminder_dialog.dart';

class MedicationReminderScreen extends StatefulWidget {
  const MedicationReminderScreen({
    super.key,
    this.repository = const RemoteMedicationReminderRepository(),
  });

  final MedicationReminderRepository repository;

  @override
  State<MedicationReminderScreen> createState() => _MedicationReminderScreenState();
}

class _MedicationReminderScreenState extends State<MedicationReminderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  List<MedicationDoseLog> _todayDoses = [];
  List<MedicationReminder> _reminders = [];
  ComplianceStats _stats = const ComplianceStats();
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _dateStr => _selectedDate.toIso8601String().substring(0, 10);

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final dosesFuture = widget.repository.getTodayDoses(date: _dateStr);
      final remindersFuture = widget.repository.getReminders();
      final statsFuture = widget.repository.getComplianceStats(days: 7);

      final results = await Future.wait([dosesFuture, remindersFuture, statsFuture]);
      if (mounted) {
        setState(() {
          _todayDoses = results[0] as List<MedicationDoseLog>;
          _reminders = results[1] as List<MedicationReminder>;
          _stats = results[2] as ComplianceStats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markDoseStatus(MedicationDoseLog dose, DoseStatus status) async {
    try {
      await widget.repository.updateDoseStatus(dose.id, status);
      if (mounted) {
        final actionText = status == DoseStatus.taken ? 'Đã uống' : 'Đã bỏ qua';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: status == DoseStatus.taken ? AppColors.success : Colors.grey.shade700,
            content: Text('$actionText liều thuốc ${dose.medicineName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _toggleReminder(MedicationReminder reminder, bool isActive) async {
    try {
      await widget.repository.toggleReminder(reminder.id, isActive);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _deleteReminder(MedicationReminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa Lời nhắc Thuốc'),
        content: Text('Bạn có chắc muốn xóa lời nhắc uống ${reminder.medicineName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repository.deleteReminder(reminder.id);
      _loadData();
    }
  }

  Future<void> _importFromPrescriptions() async {
    final completedWithPrescription = AppointmentStore.instance.appointments
        .where(
          (a) =>
              PatientSession.instance.matchesPatientId(a.patientId) &&
              a.status == AppointmentStatus.completed &&
              a.prescription != null &&
              a.prescription!.trim().isNotEmpty,
        )
        .toList();

    if (completedWithPrescription.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có toa thuốc hoàn thành nào từ bác sĩ để đồng bộ.'),
        ),
      );
      return;
    }

    final paymentRepo = LocalPaymentRepository();
    final prescriptions = <Appointment>[];
    for (final apt in completedWithPrescription) {
      final inv = await paymentRepo.getInvoiceForAppointment(apt.id);
      if (inv.isPaid) {
        prescriptions.add(apt);
      }
    }

    if (prescriptions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn có đơn thuốc chưa thanh toán viện phí. Vui lòng hoàn tất thanh toán hóa đơn để nhận thuốc và phân lịch nhắc uống!',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488)),
                const SizedBox(width: 8),
                const Text(
                  'Chọn toa thuốc bác sĩ để đồng bộ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: prescriptions.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, index) {
                  final appt = prescriptions[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${appt.doctorName} (${appt.department})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Ngày: ${appt.dateLabel} - ${appt.time}\nToa: ${appt.prescription}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: FilledButton.tonal(
                      child: const Text('Nhập'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await widget.repository.createFromPrescription(
                            prescription: appt.prescription!,
                            appointmentId: appt.id,
                            patientId: appt.patientId,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã đồng bộ đơn thuốc vào lịch nhắc thành công!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadData();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e')),
                          );
                        }
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

  Future<void> _openAddReminder() async {
    final created = await AddEditReminderDialog.show(
      context,
      repository: widget.repository,
    );
    if (created != null) {
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Đã thêm lời nhắc uống ${created.medicineName}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final takenCount = _todayDoses.where((d) => d.status == DoseStatus.taken).length;
    final totalToday = _todayDoses.length;
    final progress = totalToday > 0 ? (takenCount / totalToday) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hẹn giờ Nhắc uống thuốc'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Lịch hôm nay ($takenCount/$totalToday)',
              icon: const Icon(Icons.today_rounded),
            ),
            Tab(
              text: 'Đơn thuốc (${_reminders.length})',
              icon: const Icon(Icons.medication_liquid_rounded),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Today Schedule
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Compliance Progress Card
                        _buildProgressCard(takenCount, totalToday, progress),
                        const SizedBox(height: 20),

                        // Section Header
                        Row(
                          children: [
                            const Text(
                              'Các liều thuốc cần uống',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_todayDoses.isEmpty)
                          _buildEmptyDosesCard()
                        else
                          ..._buildDoseTimeSections(),
                      ],
                    ),
                  ),
                ),

                // Tab 2: All Active Reminders
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Danh sách thuốc đang theo dõi',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Từ toa BS'),
                              onPressed: _importFromPrescriptions,
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Thêm'),
                              onPressed: _openAddReminder,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_reminders.isEmpty)
                          _buildEmptyRemindersCard()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _reminders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final item = _reminders[idx];
                              return _buildReminderCard(item);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        icon: const Icon(Icons.alarm_add_rounded, color: Colors.white),
        label: const Text('Thêm nhắc thuốc', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _openAddReminder,
      ),
    );
  }

  Widget _buildProgressCard(int taken, int total, double progress) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tiến độ uống thuốc hôm nay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      total == 0
                          ? 'Chưa có lịch uống thuốc nào hôm nay'
                          : (taken == total
                              ? 'Tuyệt vời! Bạn đã uống đủ liều hôm nay 🎉'
                              : 'Đã hoàn thành $taken trên tổng số $total liều'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tỷ lệ hoàn thành: ${(progress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tuân thủ 7 ngày: ${_stats.complianceRate}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDoseTimeSections() {
    // Group doses into Morning, Afternoon, Evening, Night
    final morning = <MedicationDoseLog>[];
    final afternoon = <MedicationDoseLog>[];
    final evening = <MedicationDoseLog>[];
    final night = <MedicationDoseLog>[];

    for (final d in _todayDoses) {
      final hour = int.tryParse(d.time.split(':')[0]) ?? 8;
      if (hour < 11) {
        morning.add(d);
      } else if (hour < 14) {
        afternoon.add(d);
      } else if (hour < 18) {
        evening.add(d);
      } else {
        night.add(d);
      }
    }

    final widgets = <Widget>[];

    void addGroup(String title, IconData icon, Color color, List<MedicationDoseLog> list) {
      if (list.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${list.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      );

      for (final dose in list) {
        widgets.add(_buildDoseCard(dose));
        widgets.add(const SizedBox(height: 10));
      }
    }

    addGroup('Buổi Sáng (06:00 - 11:00)', Icons.wb_sunny_rounded, const Color(0xFFD97706), morning);
    addGroup('Buổi Trưa (11:00 - 14:00)', Icons.wb_cloudy_rounded, const Color(0xFF0284C7), afternoon);
    addGroup('Buổi Chiều (14:00 - 18:00)', Icons.wb_twilight_rounded, const Color(0xFF7C3AED), evening);
    addGroup('Buổi Tối (18:00 - 23:00)', Icons.bedtime_rounded, const Color(0xFF4338CA), night);

    return widgets;
  }

  Widget _buildDoseCard(MedicationDoseLog dose) {
    final isTaken = dose.status == DoseStatus.taken;
    final isSkipped = dose.status == DoseStatus.skipped;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTaken
            ? const Color(0xFF0D9488).withValues(alpha: 0.05)
            : (isSkipped ? Colors.grey.shade100 : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTaken
              ? const Color(0xFF0D9488).withValues(alpha: 0.4)
              : (isSkipped ? Colors.grey.shade300 : AppColors.border),
          width: isTaken ? 1.5 : 1,
        ),
        boxShadow: isTaken || isSkipped
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time badge & Pill icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isTaken
                  ? const Color(0xFF0D9488)
                  : const Color(0xFF0D9488).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.medication_rounded,
                  size: 20,
                  color: isTaken ? Colors.white : const Color(0xFF0D9488),
                ),
                const SizedBox(height: 2),
                Text(
                  dose.time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isTaken ? Colors.white : const Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Medicine info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicineName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: isTaken || isSkipped ? TextDecoration.none : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Liều lượng: ${dose.dosage}',
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
                if (dose.instructions.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dose.instructions,
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                  ),
                ],
                if (isTaken && dose.takenAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Đã uống lúc ${dose.takenAt!.hour.toString().padLeft(2, '0')}:${dose.takenAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          if (!isTaken && !isSkipped) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.mutedText),
              onSelected: (val) {
                if (val == 'skip') {
                  _markDoseStatus(dose, DoseStatus.skipped);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'skip',
                  child: Row(
                    children: [
                      Icon(Icons.close, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Bỏ qua liều này'),
                    ],
                  ),
                ),
              ],
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _markDoseStatus(dose, DoseStatus.taken),
              child: const Text('Đã uống', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ] else if (isTaken) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    'Hoàn thành',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isSkipped) ...[
            TextButton(
              onPressed: () => _markDoseStatus(dose, DoseStatus.taken),
              child: const Text('Uống bù', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderCard(MedicationReminder item) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  child: const Icon(Icons.medication_rounded, color: Color(0xFF0D9488)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.medicineName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${item.dosage} • ${item.timesPerDay} lần/ngày',
                        style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: item.isActive,
                  activeThumbColor: const Color(0xFF0D9488),
                  onChanged: (val) => _toggleReminder(item, val),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF0D9488)),
                const SizedBox(width: 6),
                Text(
                  'Giờ uống: ${item.reminderTimes.join(", ")}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.date_range_rounded, size: 15, color: AppColors.mutedText),
                const SizedBox(width: 6),
                Text(
                  'Đợt điều trị: ${item.daysCount} ngày (đến ${item.endDate.day}/${item.endDate.month})',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                ),
              ],
            ),
            if (item.instructions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 15, color: AppColors.mutedText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.instructions,
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Xóa', style: TextStyle(color: Colors.red, fontSize: 12)),
                  onPressed: () => _deleteReminder(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDosesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF0D9488), size: 48),
          SizedBox(height: 12),
          Text(
            'Không có liều thuốc nào cần uống hôm nay.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Hãy thêm lời nhắc mới hoặc nhập đơn thuốc từ Sổ khám bệnh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRemindersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.medication_outlined, color: AppColors.mutedText, size: 48),
          SizedBox(height: 12),
          Text(
            'Chưa có đơn thuốc nào đang theo dõi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Nhấn nút "Thêm thuốc" bên trên để tạo lịch nhắc nhở uống thuốc đầu tiên của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
