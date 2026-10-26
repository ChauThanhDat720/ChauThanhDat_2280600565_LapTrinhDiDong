import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../data/vaccination_repository.dart';
import '../domain/vaccination_record.dart';

class AddVaccinationScreen extends StatefulWidget {
  const AddVaccinationScreen({
    super.key,
    this.patientId = 'BN-01',
    this.patientName = 'Nguyễn Văn An',
    this.familyMemberId = 'fam-self',
    this.repository = const RemoteVaccinationRepository(),
  });

  final String patientId;
  final String patientName;
  final String familyMemberId;
  final VaccinationRepository repository;

  @override
  State<AddVaccinationScreen> createState() => _AddVaccinationScreenState();
}

class _AddVaccinationScreenState extends State<AddVaccinationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _vaccineNameController;
  late final TextEditingController _targetDiseaseController;
  late final TextEditingController _batchNumberController;
  late final TextEditingController _manufacturerController;
  late final TextEditingController _facilityController;
  late final TextEditingController _doctorController;
  late final TextEditingController _nurseController;
  late final TextEditingController _reactionController;

  int _doseNumber = 1;
  int _totalDoses = 3;
  DateTime _administeredDate = AppTimezone.now();
  DateTime? _nextDoseDate;
  bool _hasNextDose = false;
  bool _saving = false;

  static const List<Map<String, String>> _popularVaccines = [
    {
      'name': 'Gardasil 9 (Mỹ)',
      'target': 'Ung thư cổ tử cung, u nhú & mụn cóc sinh dục do HPV',
      'maker': 'Merck Sharp & Dohme (Mỹ)',
      'doses': '3',
    },
    {
      'name': 'Vaxigrip Tetra (Pháp)',
      'target': 'Cúm mùa tứ giá (A/H1N1, A/H3N2, B/Victoria, B/Yamagata)',
      'maker': 'Sanofi Pasteur (Pháp)',
      'doses': '1',
    },
    {
      'name': 'Engerix B 20mcg (Bỉ)',
      'target': 'Viêm gan virus B',
      'maker': 'GlaxoSmithKline - GSK (Bỉ)',
      'doses': '3',
    },
    {
      'name': 'Prevenar 13 (Mỹ)',
      'target': 'Phế cầu khuẩn & Viêm phổi',
      'maker': 'Pfizer (Mỹ)',
      'doses': '1',
    },
    {
      'name': 'Infanrix Hexa 6 trong 1 (Bỉ)',
      'target': 'Bạch hầu, Ho gà, Uốn ván, Bại liệt, Hib, Viêm gan B',
      'maker': 'GlaxoSmithKline - GSK (Bỉ)',
      'doses': '3',
    },
    {
      'name': 'Varivax (Mỹ)',
      'target': 'Thủy đậu (Trái rạ)',
      'maker': 'Merck Sharp & Dohme (Mỹ)',
      'doses': '2',
    },
  ];

  @override
  void initState() {
    super.initState();
    _vaccineNameController = TextEditingController();
    _targetDiseaseController = TextEditingController();
    _batchNumberController = TextEditingController(text: 'BATCH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    _manufacturerController = TextEditingController();
    _facilityController = TextEditingController(text: 'Bệnh viện Đa khoa Quốc tế Smart Hospital');
    _doctorController = TextEditingController(text: 'BS. Trần Thảo Linh');
    _nurseController = TextEditingController(text: 'ĐD. Lê Thị Hồng');
    _reactionController = TextEditingController(text: 'Bình thường, không sốt, không phản ứng phụ');
  }

  @override
  void dispose() {
    _vaccineNameController.dispose();
    _targetDiseaseController.dispose();
    _batchNumberController.dispose();
    _manufacturerController.dispose();
    _facilityController.dispose();
    _doctorController.dispose();
    _nurseController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  void _applyVaccineTemplate(Map<String, String> vac) {
    setState(() {
      _vaccineNameController.text = vac['name']!;
      _targetDiseaseController.text = vac['target']!;
      _manufacturerController.text = vac['maker']!;
      final total = int.tryParse(vac['doses'] ?? '3') ?? 3;
      _totalDoses = total;
      if (_doseNumber > _totalDoses) _doseNumber = _totalDoses;
      if (_doseNumber < _totalDoses) {
        _hasNextDose = true;
        _nextDoseDate = _administeredDate.add(const Duration(days: 60));
      } else {
        _hasNextDose = false;
        _nextDoseDate = null;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final certCode = 'VAC-${DateTime.now().year}-VN-${mathFloor(10000 + (DateTime.now().microsecond % 90000))}';
      final record = VaccinationRecord(
        id: 'vac-${DateTime.now().millisecondsSinceEpoch}',
        patientId: widget.patientId,
        familyMemberId: widget.familyMemberId,
        patientName: widget.patientName,
        vaccineName: _vaccineNameController.text.trim(),
        targetDisease: _targetDiseaseController.text.trim(),
        doseNumber: _doseNumber,
        totalDoses: _totalDoses,
        batchNumber: _batchNumberController.text.trim(),
        manufacturer: _manufacturerController.text.trim(),
        administeredDate: _administeredDate,
        nextDoseDate: _hasNextDose ? _nextDoseDate : null,
        facilityName: _facilityController.text.trim(),
        doctorName: _doctorController.text.trim(),
        nurseName: _nurseController.text.trim(),
        reactionStatus: _reactionController.text.trim(),
        certificateCode: certCode,
        status: 'completed',
        createdAt: AppTimezone.now(),
      );

      await widget.repository.saveVaccination(record);

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
                    'Đã lưu thông tin mũi tiêm và cấp mã chứng nhận tiêm chủng điện tử!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context, record);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int mathFloor(num val) => val.toInt();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Mũi Tiêm Vắc-Xin'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hồ sơ tiêm chủng của: ${widget.patientName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Quick selector chips
              const Text(
                'Chọn nhanh loại vắc-xin phổ biến:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _popularVaccines.map((vac) {
                  return ActionChip(
                    avatar: const Icon(Icons.vaccines_rounded, size: 16, color: AppColors.primary),
                    label: Text(vac['name']!, style: const TextStyle(fontSize: 11.5)),
                    onPressed: () => _applyVaccineTemplate(vac),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Vaccine Name
              _fieldTitle('Tên Vắc-xin *'),
              TextFormField(
                controller: _vaccineNameController,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Gardasil 9, Vaxigrip Tetra...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên vắc-xin' : null,
              ),
              const SizedBox(height: 14),

              // Target Disease
              _fieldTitle('Bệnh phòng ngừa *'),
              TextFormField(
                controller: _targetDiseaseController,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Ung thư cổ tử cung do HPV, Cúm mùa...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập bệnh phòng ngừa' : null,
              ),
              const SizedBox(height: 14),

              // Dose Number & Total Doses Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldTitle('Mũi thứ mấy'),
                        DropdownButtonFormField<int>(
                          initialValue: _doseNumber,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: List.generate(
                            _totalDoses,
                            (i) => DropdownMenuItem(value: i + 1, child: Text('Mũi ${i + 1}')),
                          ),
                          onChanged: (val) {
                            if (val != null) setState(() => _doseNumber = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldTitle('Tổng số mũi theo phác đồ'),
                        DropdownButtonFormField<int>(
                          initialValue: _totalDoses,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n mũi'))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _totalDoses = val;
                                if (_doseNumber > _totalDoses) _doseNumber = _totalDoses;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Batch & Manufacturer
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldTitle('Số lô sản xuất'),
                        TextFormField(
                          controller: _batchNumberController,
                          decoration: InputDecoration(
                            hintText: 'MSD-VN2408',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldTitle('Hãng / Nước SX'),
                        TextFormField(
                          controller: _manufacturerController,
                          decoration: InputDecoration(
                            hintText: 'MSD (Mỹ)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Administered Date Picker
              _fieldTitle('Ngày tiêm'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _administeredDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => _administeredDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(AppTimezone.date(_administeredDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Next Dose Appointment
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasNextDose,
                title: const Text('Có lịch hẹn mũi tiếp theo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                onChanged: (val) {
                  setState(() {
                    _hasNextDose = val ?? false;
                    if (_hasNextDose && _nextDoseDate == null) {
                      _nextDoseDate = _administeredDate.add(const Duration(days: 30));
                    }
                  });
                },
              ),
              if (_hasNextDose) ...[
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _nextDoseDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => _nextDoseDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_add_rounded, size: 20, color: Color(0xFFD97706)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Lịch tiêm mũi tiếp theo: ${_nextDoseDate != null ? AppTimezone.date(_nextDoseDate!) : "Chưa chọn"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFFD97706)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Facility & Doctor
              _fieldTitle('Cơ sở y tế tiêm chủng'),
              TextFormField(
                controller: _facilityController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Reaction status
              _fieldTitle('Phản ứng theo dõi 30 phút sau tiêm'),
              TextFormField(
                controller: _reactionController,
                decoration: InputDecoration(
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
                  'Bình thường, không sốt',
                  'Sốt nhẹ < 38°C',
                  'Vết tiêm sưng đỏ nhẹ',
                  'Mệt mỏi thoáng qua',
                ].map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _reactionController.text = s,
                )).toList(),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _saving ? 'Đang lưu mũi tiêm...' : 'Lưu Vào Sổ & Cấp Hộ Chiếu Vắc-Xin',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _saving ? null : _submit,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
      ),
    );
  }
}
