import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../../appointments/domain/appointment.dart';
import '../data/clinical_intake_repository.dart';
import '../domain/clinical_intake.dart';

class PreVisitIntakeScreen extends StatefulWidget {
  const PreVisitIntakeScreen({
    super.key,
    required this.appointment,
    this.repository = const RemoteClinicalIntakeRepository(),
  });

  final Appointment appointment;
  final ClinicalIntakeRepository repository;

  @override
  State<PreVisitIntakeScreen> createState() => _PreVisitIntakeScreenState();
}

class _PreVisitIntakeScreenState extends State<PreVisitIntakeScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _chiefComplaintController;
  late final TextEditingController _notesController;
  late final TextEditingController _currentMedicationsController;
  late final TextEditingController _medicalHistoryController;
  late final TextEditingController _knownAllergiesController;

  int _painLevel = 5;
  String _painLocation = 'Ngực / Tim mạch';
  String _onsetDuration = '1 - 3 ngày trước';
  final Set<String> _selectedSymptoms = {};
  bool _submitting = false;

  static const List<String> _locationOptions = [
    'Ngực / Tim mạch',
    'Đầu / Não',
    'Bụng / Tiêu hóa',
    'Hô hấp / Phổi',
    'Cơ xương khớp',
    'Tai Mũi Họng',
    'Toàn thân',
  ];

  static const List<String> _durationOptions = [
    'Hôm nay (< 24h)',
    '1 - 3 ngày trước',
    '1 tuần nay',
    '2 - 4 tuần',
    'Hơn 1 tháng',
  ];

  static const List<String> _commonSymptoms = [
    'Đau thắt ngực',
    'Đau nhói',
    'Đau âm ỉ',
    'Khó thở khi gắng sức',
    'Khó thở khi nằm',
    'Hồi hộp đánh trống ngực',
    'Buồn nôn / Nôn',
    'Chóng mặt / Choáng',
    'Mất ngủ',
    'Sốt / Ớn lạnh',
    'Vã mồ hôi lạnh',
    'Ho kéo dài',
    'Tê bì chân tay',
  ];

  @override
  void initState() {
    super.initState();
    final existing = ClinicalIntakeStore.instance.getByAppointmentId(widget.appointment.id);

    _chiefComplaintController = TextEditingController(
      text: existing?.chiefComplaint.isNotEmpty == true
          ? existing!.chiefComplaint
          : widget.appointment.reason,
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _currentMedicationsController =
        TextEditingController(text: existing?.currentMedications ?? '');
    _medicalHistoryController =
        TextEditingController(text: existing?.medicalHistory ?? '');
    _knownAllergiesController =
        TextEditingController(text: existing?.knownAllergies ?? '');

    if (existing != null) {
      _painLevel = existing.painLevel;
      _painLocation = existing.painLocation;
      _onsetDuration = existing.onsetDuration;
      _selectedSymptoms.addAll(existing.symptoms);
    } else {
      _selectedSymptoms.addAll(['Đau thắt ngực', 'Khó thở khi gắng sức']);
    }
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _notesController.dispose();
    _currentMedicationsController.dispose();
    _medicalHistoryController.dispose();
    _knownAllergiesController.dispose();
    super.dispose();
  }

  String _getPainSeverity(int level) {
    if (level <= 3) return 'Nhẹ (1-3) - Sinh hoạt bình thường';
    if (level <= 6) return 'Vừa phải (4-6) - Khó chịu, ảnh hưởng nhẹ';
    if (level <= 8) return 'Dữ dội (7-8) - Đau nhiều, cản trở sinh hoạt';
    return 'Rất dữ dội (9-10) - Đau đớn tột cùng';
  }

  String _getPainEmoji(int level) {
    if (level <= 2) return '😊';
    if (level <= 4) return '😐';
    if (level <= 6) return '🙁';
    if (level <= 8) return '😣';
    return '😭';
  }

  Color _getPainColor(int level) {
    if (level <= 3) return const Color(0xFF16A34A);
    if (level <= 6) return const Color(0xFFD97706);
    if (level <= 8) return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final intake = ClinicalIntake(
        id: 'intake-${widget.appointment.id}',
        appointmentId: widget.appointment.id,
        patientId: widget.appointment.patientId,
        chiefComplaint: _chiefComplaintController.text.trim(),
        painLocation: _painLocation,
        onsetDuration: _onsetDuration,
        painLevel: _painLevel,
        symptoms: _selectedSymptoms.toList(),
        currentMedications: _currentMedicationsController.text.trim(),
        medicalHistory: _medicalHistoryController.text.trim(),
        knownAllergies: _knownAllergiesController.text.trim(),
        notes: _notesController.text.trim(),
        submittedAt: AppTimezone.now(),
      );

      await widget.repository.saveIntake(intake);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0D9488),
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã nộp phiếu khai báo! Bác sĩ sẽ xem bản tóm tắt này khi bắt đầu ca khám.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context, intake);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Lỗi lưu phiếu khai báo: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final painColor = _getPainColor(_painLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khai Báo Triệu Chứng Tiền Khám'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0D9488), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chuẩn bị thông tin trước khi gặp Bác sĩ',
                            style: TextStyle(
                              color: Color(0xFF0F766E),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Điền thông tin này giúp Bác sĩ ${widget.appointment.doctorName} nắm trước bệnh sử trong 30 giây, dành toàn bộ thời gian khám để chẩn đoán chuyên sâu.',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF134E4A), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Section 1: Chief Complaint
              _sectionHeader(
                icon: Icons.chat_bubble_outline_rounded,
                title: '1. Triệu chứng khó chịu chính (Lý do khám)',
                required: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _chiefComplaintController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Mô tả ngắn gọn cảm giác khó chịu nhất hiện tại của bạn...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập triệu chứng chính của bạn';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Đau thắt ngực trái',
                  'Khó thở hụt hơi',
                  'Đau đầu dữ dội',
                  'Đau vùng thượng vị',
                  'Chóng mặt hoa mắt',
                ].map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 11.5)),
                  onPressed: () {
                    final curr = _chiefComplaintController.text.trim();
                    _chiefComplaintController.text = curr.isEmpty ? s : '$curr, $s';
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),

              // Section 2: Pain Location
              _sectionHeader(
                icon: Icons.accessibility_new_rounded,
                title: '2. Vị trí khó chịu / đau nhất',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _locationOptions.map((loc) {
                  final selected = _painLocation == loc;
                  return ChoiceChip(
                    label: Text(loc),
                    selected: selected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary : AppColors.text,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _painLocation = loc);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Section 3: Onset Duration
              _sectionHeader(
                icon: Icons.schedule_rounded,
                title: '3. Triệu chứng bắt đầu xuất hiện từ khi nào?',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationOptions.map((dur) {
                  final selected = _onsetDuration == dur;
                  return ChoiceChip(
                    label: Text(dur),
                    selected: selected,
                    selectedColor: const Color(0xFFE0F2FE),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFF0369A1) : AppColors.text,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _onsetDuration = dur);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Section 4: Visual Pain Scale (VAS 1 - 10)
              _sectionHeader(
                icon: Icons.sentiment_very_dissatisfied_rounded,
                title: '4. Thang điểm đau trực quan (VAS 1 - 10)',
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: painColor.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: painColor.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getPainEmoji(_painLevel),
                          style: const TextStyle(fontSize: 36),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mức độ: $_painLevel / 10',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: painColor,
                              ),
                            ),
                            Text(
                              _getPainSeverity(_painLevel),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: painColor,
                        thumbColor: painColor,
                        overlayColor: painColor.withValues(alpha: 0.2),
                        valueIndicatorColor: painColor,
                      ),
                      child: Slider(
                        value: _painLevel.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '$_painLevel/10',
                        onChanged: (val) {
                          setState(() => _painLevel = val.round());
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1: Hầu như không đau', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text('10: Cực kỳ dữ dội', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 5: Associated Symptoms
              _sectionHeader(
                icon: Icons.checklist_rounded,
                title: '5. Các triệu chứng đi kèm (Chọn nhiều)',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonSymptoms.map((sym) {
                  final isSelected = _selectedSymptoms.contains(sym);
                  return FilterChip(
                    label: Text(sym),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.text,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSymptoms.add(sym);
                        } else {
                          _selectedSymptoms.remove(sym);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Section 6: Home Medications
              _sectionHeader(
                icon: Icons.medication_rounded,
                title: '6. Các loại thuốc đang uống tại nhà',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentMedicationsController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Tên thuốc, thực phẩm chức năng đang dùng (Ví dụ: Panadol, thuốc huyết áp, vitamin...)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Không uống thuốc gì',
                  'Panadol / Paracetamol',
                  'Thuốc hạ huyết áp',
                  'Thuốc tiểu đường',
                  'Thực phẩm chức năng',
                ].map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 11.5)),
                  onPressed: () {
                    final curr = _currentMedicationsController.text.trim();
                    _currentMedicationsController.text = curr.isEmpty ? s : '$curr, $s';
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),

              // Section 7: Medical History
              _sectionHeader(
                icon: Icons.history_edu_rounded,
                title: '7. Tiền sử bệnh nền & Phẫu thuật',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _medicalHistoryController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Bệnh nền (Ví dụ: Tăng huyết áp 2 năm, tiểu đường type 2, tiền sử mổ ruột thừa...)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Section 8: Allergies Alert
              _sectionHeader(
                icon: Icons.warning_amber_rounded,
                title: '8. Tiền sử dị ứng thuốc & Thực phẩm',
                color: const Color(0xFFDC2626),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ Cực kỳ quan trọng: Giúp Bác sĩ tránh kê đơn các hoạt chất gây dị ứng nguy hiểm.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _knownAllergiesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Dị ứng Penicillin (nổi mẩn ngứa), dị ứng Aspirin, dị ứng hải sản...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        'Không có tiền sử dị ứng thuốc',
                        'Dị ứng Penicillin / Amoxicillin',
                        'Dị ứng Aspirin / NSAIDs',
                        'Dị ứng thức ăn / Hải sản',
                      ].map((s) => ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 11.5)),
                        onPressed: () {
                          _knownAllergiesController.text = s;
                        },
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 9: Additional Notes
              _sectionHeader(
                icon: Icons.note_alt_outlined,
                title: '9. Ghi chú & Câu hỏi muốn Bác sĩ giải đáp',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Những thắc mắc hoặc điều bạn muốn Bác sĩ lưu ý thêm...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 22),
                  label: Text(
                    _submitting ? 'Đang lưu phiếu...' : 'Xác Nhận & Gửi Cho Bác Sĩ',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _submitting ? null : _submit,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    bool required = false,
    Color? color,
  }) {
    final effectiveColor = color ?? AppColors.primary;
    return Row(
      children: [
        Icon(icon, color: effectiveColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor == const Color(0xFFDC2626) ? effectiveColor : AppColors.text,
                  ),
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
