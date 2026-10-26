import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/health_vitals_repository.dart';
import '../domain/health_vital.dart';

class RecordVitalDialog extends StatefulWidget {
  const RecordVitalDialog({
    super.key,
    required this.repository,
    this.patientId = 'patient-1',
  });

  final HealthVitalsRepository repository;
  final String patientId;

  static Future<HealthVital?> show(
    BuildContext context, {
    required HealthVitalsRepository repository,
    String patientId = 'patient-1',
  }) {
    return showModalBottomSheet<HealthVital>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordVitalDialog(
        repository: repository,
        patientId: patientId,
      ),
    );
  }

  @override
  State<RecordVitalDialog> createState() => _RecordVitalDialogState();
}

class _RecordVitalDialogState extends State<RecordVitalDialog> {
  final _formKey = GlobalKey<FormState>();

  final _sysController = TextEditingController(text: '120');
  final _diaController = TextEditingController(text: '80');
  final _hrController = TextEditingController(text: '75');
  final _bsController = TextEditingController(text: '5.6');
  final _weightController = TextEditingController(text: '65.0');
  final _heightController = TextEditingController(text: '170.0');
  final _noteController = TextEditingController();

  String _bloodSugarCondition = 'fasting';
  bool _saving = false;

  @override
  void dispose() {
    _sysController.dispose();
    _diaController.dispose();
    _hrController.dispose();
    _bsController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _calculatedBmi {
    final w = double.tryParse(_weightController.text);
    final h = double.tryParse(_heightController.text);
    if (w != null && h != null && h > 0) {
      final hm = h > 3 ? h / 100 : h;
      final bmi = w / (hm * hm);
      return ((bmi * 10).round()) / 10;
    }
    return null;
  }

  BloodPressureCategory get _currentBpCategory {
    final sys = int.tryParse(_sysController.text) ?? 120;
    final dia = int.tryParse(_diaController.text) ?? 80;
    if (sys >= 160 || dia >= 100) return BloodPressureCategory.hypertensionStage2;
    if (sys >= 140 || dia >= 90) return BloodPressureCategory.hypertensionStage1;
    if (sys >= 120 || dia >= 80) return BloodPressureCategory.prehypertension;
    if (sys >= 90 && dia >= 60) return BloodPressureCategory.optimal;
    return BloodPressureCategory.low;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final vital = HealthVital(
        id: '',
        patientId: widget.patientId,
        systolic: int.parse(_sysController.text.trim()),
        diastolic: int.parse(_diaController.text.trim()),
        heartRate: int.tryParse(_hrController.text.trim()),
        bloodSugar: double.tryParse(_bsController.text.trim()),
        bloodSugarCondition: _bloodSugarCondition,
        weight: double.tryParse(_weightController.text.trim()),
        height: double.tryParse(_heightController.text.trim()),
        bmi: _calculatedBmi,
        note: _noteController.text.trim(),
        recordedBy: 'patient',
        recordedAt: DateTime.now(),
      );

      final result = await widget.repository.recordVital(vital);
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
    final bpCategory = _currentBpCategory;
    final bmi = _calculatedBmi;

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
                    child: const Icon(Icons.favorite_rounded, color: Color(0xFF0D9488)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Ghi nhận Chỉ số Sinh hiệu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Realtime Blood Pressure Preview Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bpCategory.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bpCategory.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.monitor_heart_rounded, color: bpCategory.color, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phân loại: ${bpCategory.label}',
                            style: TextStyle(
                              color: bpCategory.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Theo chuẩn WHO / Bộ Y tế Việt Nam',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Blood Pressure Inputs (Systolic / Diastolic)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sysController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Tâm thu (Systolic)',
                        hintText: '120',
                        suffixText: 'mmHg',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        final n = int.tryParse(val ?? '');
                        if (n == null || n < 50 || n > 250) return '50 - 250';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _diaController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Tâm trương (Diastolic)',
                        hintText: '80',
                        suffixText: 'mmHg',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        final n = int.tryParse(val ?? '');
                        if (n == null || n < 30 || n > 180) return '30 - 180';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Heart Rate & Blood Glucose
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hrController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nhịp tim',
                        hintText: '75',
                        suffixText: 'bpm',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _bsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Đường huyết',
                        hintText: '5.6',
                        suffixText: 'mmol/L',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Blood glucose condition selector
              Row(
                children: [
                  const Text('Thời điểm đo đường huyết:', style: TextStyle(fontSize: 12, color: AppColors.mutedText)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _bloodSugarCondition,
                    underline: const SizedBox(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'fasting', child: Text('Lúc đói (Sáng)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'postprandial', child: Text('Sau ăn 2h', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'random', child: Text('Ngẫu nhiên', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _bloodSugarCondition = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Weight & Height
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Cân nặng',
                        hintText: '65.0',
                        suffixText: 'kg',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Chiều cao',
                        hintText: '170.0',
                        suffixText: 'cm',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              if (bmi != null) ...[
                const SizedBox(height: 8),
                Text(
                  '👉 Chỉ số BMI ước tính: $bmi (${bmi < 18.5 ? "Gầy" : (bmi <= 24.9 ? "Bình thường" : (bmi <= 29.9 ? "Thừa cân" : "Béo phì"))})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                ),
              ],
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Ghi chú thêm',
                  hintText: 'Ví dụ: Đo sau khi uống thuốc huyết áp, vừa đi bộ...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
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
                          'Lưu Chỉ Số Sinh Hiệu',
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
