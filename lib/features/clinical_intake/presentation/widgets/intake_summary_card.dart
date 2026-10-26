import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/clinical_intake.dart';

class IntakeSummaryCard extends StatelessWidget {
  const IntakeSummaryCard({
    super.key,
    required this.intake,
    this.onTapEdit,
    this.isDoctorView = false,
  });

  final ClinicalIntake intake;
  final VoidCallback? onTapEdit;
  final bool isDoctorView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: const Color(0xFF0D9488).withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDoctorView
                        ? 'BÁO CÁO TRIỆU CHỨNG TIỀN KHÁM (INTAKE SUMMARY)'
                        : 'PHIẾU KHAI BÁO TRIỆU CHỨNG TIỀN KHÁM',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                _buildPainBadge(),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chief Complaint & Pain Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.accessibility_new_rounded, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            intake.chiefComplaint.isNotEmpty
                                ? intake.chiefComplaint
                                : 'Đau và khó chịu theo lý do khám ban đầu',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vị trí: ${intake.painLocation} • Khởi phát: ${intake.onsetDuration}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Symptoms chips
                if (intake.symptoms.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: intake.symptoms.map((symptom) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          symptom,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Current Medications & Allergies
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      if (intake.currentMedications.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💊 Thuốc đang uống: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Expanded(
                              child: Text(intake.currentMedications, style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (intake.knownAllergies.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⚠️ Dị ứng đã biết: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626))),
                            Expanded(
                              child: Text(
                                intake.knownAllergies,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (intake.medicalHistory.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🩺 Tiền sử bệnh: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Expanded(
                              child: Text(intake.medicalHistory, style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                if (intake.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ghi chú của bệnh nhân: "${intake.notes}"',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                  ),
                ],

                if (onTapEdit != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onTapEdit,
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Cập nhật thông tin phiếu', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPainBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: intake.painColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: intake.painColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(intake.painEmoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            'VAS: ${intake.painLevel}/10',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: intake.painColor,
            ),
          ),
        ],
      ),
    );
  }
}
