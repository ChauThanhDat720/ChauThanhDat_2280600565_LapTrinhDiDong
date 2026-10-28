import 'package:flutter/material.dart';

enum TriageUrgency {
  emergency('🚨 CẤP CỨU KHẨN CẤP', Color(0xFFDC2626), 'Cần can thiệp y tế ngay lập tức trong vòng 15-30 phút'),
  urgent('⚠️ CẦN KHÁM TRONG NGÀY', Color(0xFFEA580C), 'Nên đến bệnh viện khám sớm trong ngày'),
  routine('🟢 KHÁM THƯỜNG QUY', Color(0xFF0D9488), 'Đặt lịch khám theo giờ hẹn phù hợp'),
  selfCare('ℹ️ THEO DÕI TẠI NHÀ', Color(0xFF2563EB), 'Triệu chứng nhẹ, có thể theo dõi và nghỉ ngơi');

  const TriageUrgency(this.label, this.color, this.description);
  final String label;
  final Color color;
  final String description;
}

class TriageResult {
  const TriageResult({
    required this.symptoms,
    required this.urgency,
    required this.suggestedDepartment,
    required this.departmentId,
    required this.suggestedDoctorId,
    required this.suggestedDoctorName,
    required this.possibleConditions,
    required this.advice,
    required this.warningFlags,
  });

  final String symptoms;
  final TriageUrgency urgency;
  final String suggestedDepartment;
  final String departmentId;
  final String suggestedDoctorId;
  final String suggestedDoctorName;
  final List<String> possibleConditions;
  final String advice;
  final List<String> warningFlags;
}
