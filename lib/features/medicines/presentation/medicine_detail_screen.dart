import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/medicine.dart';

class MedicineDetailScreen extends StatelessWidget {
  const MedicineDetailScreen({
    super.key,
    required this.medicine,
  });

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(medicine.name),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.medication_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              medicine.activeIngredient,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          medicine.category,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          medicine.dosageForm,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (medicine.brandNames.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Tên thương mại: ${medicine.brandNames}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Indications
            _buildSectionCard(
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.primary,
              title: 'Chỉ định & Công dụng điều trị',
              content: medicine.indications,
              backgroundColor: AppColors.primary.withValues(alpha: 0.04),
              borderColor: AppColors.primary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 14),

            // Section 2: Dosage & Instructions
            _buildSectionCard(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF0D9488),
              title: 'Liều dùng & Cách dùng chuẩn',
              content: medicine.dosageInstructions,
              backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.04),
              borderColor: const Color(0xFF0D9488).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 14),

            // Section 3: Side Effects
            _buildSectionCard(
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.amber.shade800,
              title: 'Tác dụng phụ thường gặp & Nguy cơ',
              content: medicine.sideEffects,
              backgroundColor: Colors.amber.withValues(alpha: 0.06),
              borderColor: Colors.amber.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 14),

            // Section 4: Contraindications
            _buildSectionCard(
              icon: Icons.do_not_disturb_on_rounded,
              iconColor: Colors.red.shade700,
              title: 'Chống chỉ định (Tuyệt đối không dùng)',
              content: medicine.contraindications,
              backgroundColor: Colors.red.withValues(alpha: 0.05),
              borderColor: Colors.red.withValues(alpha: 0.2),
            ),

            if (medicine.precautions != null && medicine.precautions!.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Section 5: Precautions
              _buildSectionCard(
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFF6366F1),
                title: 'Thận trọng & Dặn dò y tế',
                content: medicine.precautions!,
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.04),
                borderColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
