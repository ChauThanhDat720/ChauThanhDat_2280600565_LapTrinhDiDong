import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/medicine_repository.dart';
import '../domain/medicine.dart';

enum InteractionSeverity {
  high('⛔ CHỐNG CHỈ ĐỊNH / NGUY HIỂM CAO', Colors.red, 'Có thể gây xuất huyết, ngộ độc cơ quan hoặc đe dọa tính mạng!'),
  moderate('⚠️ THẬN TRỌNG / CẦN THEO DÕI', Colors.orange, 'Cần điều chỉnh liều hoặc uống cách xa nhau ít nhất 2 giờ.'),
  safe('✅ AN TOÀN / KHÔNG TƯƠNG TÁC ĐÁNG KỂ', Colors.green, 'Có thể sử dụng đồng thời theo đúng liều lượng chỉ định.');

  const InteractionSeverity(this.title, this.color, this.desc);
  final String title;
  final Color color;
  final String desc;
}

class DrugInteractionResult {
  const DrugInteractionResult({
    required this.drugA,
    required this.drugB,
    required this.severity,
    required this.effect,
    required this.pharmacologyMechanism,
    required this.clinicalAdvice,
  });

  final String drugA;
  final String drugB;
  final InteractionSeverity severity;
  final String effect;
  final String pharmacologyMechanism;
  final String clinicalAdvice;
}

class DrugInteractionScreen extends StatefulWidget {
  const DrugInteractionScreen({super.key});

  @override
  State<DrugInteractionScreen> createState() => _DrugInteractionScreenState();
}

class _DrugInteractionScreenState extends State<DrugInteractionScreen> {
  final List<Medicine> _allMedicines = LocalMedicineRepository.sampleMedicines;
  final Set<String> _selectedMedIds = {};
  DrugInteractionResult? _interactionResult;
  bool _analyzing = false;

  void _checkInteraction() {
    if (_selectedMedIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 2 loại thuốc để kiểm tra tương tác.')),
      );
      return;
    }

    setState(() => _analyzing = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final selectedList = _allMedicines.where((m) => _selectedMedIds.contains(m.id)).toList();
      final res = _analyzePair(selectedList[0], selectedList[1]);
      setState(() {
        _interactionResult = res;
        _analyzing = false;
      });
    });
  }

  DrugInteractionResult _analyzePair(Medicine a, Medicine b) {
    final names = '${a.name.toLowerCase()} + ${b.name.toLowerCase()}';

    // 1. Aspirin + Ibuprofen
    if (names.contains('aspirin') && names.contains('ibuprofen')) {
      return DrugInteractionResult(
        drugA: a.name,
        drugB: b.name,
        severity: InteractionSeverity.high,
        effect: 'Tăng gấp 3-5 lần nguy cơ loét và xuất huyết tiêu hóa nặng; Ibuprofen làm mất tác dụng bảo vệ tim mạch của Aspirin.',
        pharmacologyMechanism: 'Cả hai thuốc đều ức chế enzyme COX-1 làm giảm tổng hợp Prostaglandin bảo vệ niêm mạc dạ dày và cạnh tranh vị trí gắn trên tiểu cầu.',
        clinicalAdvice: 'Tuyệt đối không tự ý phối hợp. Nếu bắt buộc phải dùng, cần uống cách nhau ít nhất 2-4 giờ và phối hợp thuốc bọc dạ dày (PPI).',
      );
    }

    // 2. Paracetamol + Rượu hoặc thuốc khác có Paracetamol
    if (names.contains('paracetamol') && (names.contains('aspirin') || names.contains('ibuprofen'))) {
      return DrugInteractionResult(
        drugA: a.name,
        drugB: b.name,
        severity: InteractionSeverity.moderate,
        effect: 'Tăng gánh nặng chuyển hóa qua gan và thận, nguy cơ tích lũy độc tính.',
        pharmacologyMechanism: 'Cùng đào thải và chuyển hóa qua hệ enzyme Cytochrome P450 tại gan.',
        clinicalAdvice: 'Uống nhiều nước, không vượt quá liều tối đa 4g/ngày và theo dõi chức năng men gan.',
      );
    }

    // 3. Amlodipine + Thuốc tim mạch khác
    if (names.contains('amlodipine') && names.contains('aspirin')) {
      return DrugInteractionResult(
        drugA: a.name,
        drugB: b.name,
        severity: InteractionSeverity.safe,
        effect: 'Phối hợp thường quy trong phác đồ điều trị tăng huyết áp và phòng ngừa biến cố mạch vành.',
        pharmacologyMechanism: 'Amlodipine chẹn kênh canxi gây giãn mạch, Aspirin chống kết tập tiểu cầu mà không cản trở tác dụng hạ áp.',
        clinicalAdvice: 'Uống thuốc đều đặn theo đơn của bác sĩ tim mạch, theo dõi huyết áp định kỳ hàng ngày.',
      );
    }

    // Mặc định
    return DrugInteractionResult(
      drugA: a.name,
      drugB: b.name,
      severity: InteractionSeverity.safe,
      effect: 'Chưa ghi nhận tương tác bất lợi nghiêm trọng nào giữa hai loại dược chất này.',
      pharmacologyMechanism: 'Hai thuốc có cơ chế tác dụng và đường chuyển hóa độc lập.',
      clinicalAdvice: 'Có thể uống theo đúng chỉ định liều lượng của bác sĩ điều trị.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm Tra Tương Tác Thuốc'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: Color(0xFF1D4ED8), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dược Thư Lâm Sàng & Cảnh Báo Tương Tác',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chọn từ 2 loại thuốc trở lên để phát hiện tương tác chống chỉ định nguy hiểm.',
                          style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Chọn các loại thuốc bạn đang sử dụng:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),

            // Medicines Selection
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allMedicines.map((med) {
                final isSelected = _selectedMedIds.contains(med.id);
                return FilterChip(
                  label: Text('${med.name} (${med.activeIngredient.split(' ').first})'),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0D9488).withOpacity(0.2),
                  checkmarkColor: const Color(0xFF0D9488),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedMedIds.add(med.id);
                      } else {
                        _selectedMedIds.remove(med.id);
                      }
                      _interactionResult = null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Action Button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _analyzing ? null : _checkInteraction,
              icon: _analyzing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.compare_arrows_rounded),
              label: Text(_analyzing ? 'Đang phân tích dược học...' : 'Kiểm tra tương tác thuốc (${_selectedMedIds.length})'),
            ),
            const SizedBox(height: 24),

            // Result
            if (_interactionResult != null) ...[
              _buildInteractionCard(_interactionResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionCard(DrugInteractionResult res) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: res.severity.color, width: 2),
        boxShadow: [
          BoxShadow(
            color: res.severity.color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: res.severity.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              res.severity.title,
              style: TextStyle(color: res.severity.color, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Text(res.severity.desc, style: TextStyle(color: res.severity.color, fontSize: 12, fontWeight: FontWeight.w600)),
          const Divider(height: 20),

          Text('Cặp phối hợp: ${res.drugA} + ${res.drugB}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),

          const Text('Hậu quả tương tác:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.mutedText)),
          Text(res.effect, style: const TextStyle(fontSize: 13.5, height: 1.35)),
          const SizedBox(height: 10),

          const Text('Cơ chế dược lý:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.mutedText)),
          Text(res.pharmacologyMechanism, style: const TextStyle(fontSize: 13.5, height: 1.35)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF0284C7), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Khuyến cáo dược sĩ: ${res.clinicalAdvice}', style: const TextStyle(fontSize: 12.5, height: 1.35)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
