import 'package:flutter/material.dart';
import '../data/medication_reminder_repository.dart';
import '../domain/medication_reminder.dart';

class AddEditReminderDialog extends StatefulWidget {
  const AddEditReminderDialog({
    super.key,
    required this.repository,
    this.initialReminder,
  });

  final MedicationReminderRepository repository;
  final MedicationReminder? initialReminder;

  static Future<MedicationReminder?> show(
    BuildContext context, {
    required MedicationReminderRepository repository,
    MedicationReminder? initialReminder,
  }) {
    return showModalBottomSheet<MedicationReminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditReminderDialog(
        repository: repository,
        initialReminder: initialReminder,
      ),
    );
  }

  @override
  State<AddEditReminderDialog> createState() => _AddEditReminderDialogState();
}

class _AddEditReminderDialogState extends State<AddEditReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _instructionsController;

  int _timesPerDay = 2;
  int _daysCount = 7;
  List<String> _reminderTimes = ['08:00', '20:00'];
  bool _saving = false;

  final List<String> _instructionSuggestions = [
    'Uống sau bữa ăn 30 phút',
    'Uống trước bữa ăn 30 phút',
    'Uống khi bụng đói với nhiều nước',
    'Uống trước khi đi ngủ',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.initialReminder;
    _nameController = TextEditingController(text: r?.medicineName ?? '');
    _dosageController = TextEditingController(text: r?.dosage ?? '1 viên');
    _instructionsController = TextEditingController(
      text: r?.instructions ?? 'Uống sau bữa ăn 30 phút',
    );
    if (r != null) {
      _timesPerDay = r.timesPerDay;
      _daysCount = r.daysCount;
      _reminderTimes = List<String>.from(r.reminderTimes);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _onTimesPerDayChanged(int times) {
    setState(() {
      _timesPerDay = times;
      if (times == 1) {
        _reminderTimes = ['08:00'];
      } else if (times == 2) {
        _reminderTimes = ['08:00', '20:00'];
      } else if (times == 3) {
        _reminderTimes = ['08:00', '13:00', '20:00'];
      } else if (times == 4) {
        _reminderTimes = ['07:00', '12:00', '17:00', '21:00'];
      }
    });
  }

  Future<void> _pickTime(int index) async {
    final curParts = _reminderTimes[index].split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(curParts[0]) ?? 8,
      minute: int.tryParse(curParts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null && mounted) {
      setState(() {
        final h = picked.hour.toString().padLeft(2, '0');
        final m = picked.minute.toString().padLeft(2, '0');
        _reminderTimes[index] = '$h:$m';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final reminder = MedicationReminder(
        id: widget.initialReminder?.id ?? '',
        patientId: widget.initialReminder?.patientId ?? 'patient-1',
        medicineName: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        instructions: _instructionsController.text.trim(),
        timesPerDay: _timesPerDay,
        reminderTimes: _reminderTimes,
        startDate: widget.initialReminder?.startDate ?? now,
        daysCount: _daysCount,
        endDate: (widget.initialReminder?.startDate ?? now).add(Duration(days: _daysCount)),
        colorCode: widget.initialReminder?.colorCode ?? '#0D9488',
        isActive: widget.initialReminder?.isActive ?? true,
      );

      final result = await widget.repository.createReminder(reminder);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.alarm_add_rounded, color: Color(0xFF0D9488)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.initialReminder != null
                        ? 'Chỉnh sửa Lời nhắc Thuốc'
                        : 'Thêm Lời nhắc Uống thuốc',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Medicine Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tên thuốc (*)',
                  hintText: 'Ví dụ: Paracetamol 500mg, Amoxicillin...',
                  prefixIcon: const Icon(Icons.medication_rounded, color: Color(0xFF0D9488)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên thuốc';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Dosage
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  labelText: 'Liều lượng mỗi lần uống',
                  hintText: 'Ví dụ: 1 viên, 2 viên, 1 gói...',
                  prefixIcon: const Icon(Icons.numbers_rounded, color: Color(0xFF0D9488)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Instructions
              TextFormField(
                controller: _instructionsController,
                decoration: InputDecoration(
                  labelText: 'Hướng dẫn sử dụng',
                  hintText: 'Ví dụ: Uống sau ăn 30 phút...',
                  prefixIcon: const Icon(Icons.info_outline_rounded, color: Color(0xFF0D9488)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _instructionSuggestions.map((s) {
                  return ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    onPressed: () => _instructionsController.text = s,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Frequency (Times per day)
              const Text('Số lần uống trong ngày:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [1, 2, 3, 4].map((times) {
                  final isSelected = _timesPerDay == times;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text('$times lần/ngày', style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                        onSelected: (_) => _onTimesPerDayChanged(times),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Reminder Times List
              const Text('Khung giờ uống:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: List.generate(_reminderTimes.length, (idx) {
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0D9488)),
                    label: Text(
                      'Lần ${idx + 1}: ${_reminderTimes[idx]}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    onPressed: () => _pickTime(idx),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Days count
              Row(
                children: [
                  const Text('Thời gian uống:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _daysCount,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 ngày')),
                      DropdownMenuItem(value: 5, child: Text('5 ngày')),
                      DropdownMenuItem(value: 7, child: Text('7 ngày (1 tuần)')),
                      DropdownMenuItem(value: 10, child: Text('10 ngày')),
                      DropdownMenuItem(value: 14, child: Text('14 ngày (2 tuần)')),
                      DropdownMenuItem(value: 30, child: Text('30 ngày (1 tháng)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _daysCount = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Lưu Lời Nhắc',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
