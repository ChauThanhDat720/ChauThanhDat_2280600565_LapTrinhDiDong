import 'package:flutter/material.dart';

enum BloodPressureCategory {
  optimal('Huyết áp tối ưu', Color(0xFF0D9488)),
  prehypertension('Tiền tăng huyết áp', Color(0xFFD97706)),
  hypertensionStage1('Tăng huyết áp độ 1', Color(0xFFEA580C)),
  hypertensionStage2('Tăng huyết áp độ 2 (Nguy hiểm)', Color(0xFFDC2626)),
  low('Huyết áp thấp', Color(0xFF2563EB));

  const BloodPressureCategory(this.label, this.color);
  final String label;
  final Color color;
}

enum BmiCategory {
  underweight('Thiếu cân / Gầy', Color(0xFF2563EB)),
  normal('Thể trạng chuẩn', Color(0xFF0D9488)),
  overweight('Thừa cân', Color(0xFFD97706)),
  obese('Béo phì', Color(0xFFDC2626));

  const BmiCategory(this.label, this.color);
  final String label;
  final Color color;
}

class HealthVital {
  const HealthVital({
    required this.id,
    required this.patientId,
    this.appointmentId,
    required this.systolic,
    required this.diastolic,
    this.heartRate,
    this.bloodSugar,
    this.bloodSugarCondition = 'fasting',
    this.weight,
    this.height,
    this.bmi,
    this.healthStatus = 'optimal',
    this.healthNote = '',
    this.note = '',
    this.recordedBy = 'patient',
    required this.recordedAt,
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String? appointmentId;
  final int systolic;
  final int diastolic;
  final int? heartRate;
  final double? bloodSugar;
  final String bloodSugarCondition;
  final double? weight;
  final double? height;
  final double? bmi;
  final String healthStatus;
  final String healthNote;
  final String note;
  final String recordedBy;
  final DateTime recordedAt;
  final DateTime? createdAt;

  BloodPressureCategory get bpCategory {
    if (systolic >= 160 || diastolic >= 100) return BloodPressureCategory.hypertensionStage2;
    if (systolic >= 140 || diastolic >= 90) return BloodPressureCategory.hypertensionStage1;
    if (systolic >= 120 || diastolic >= 80) return BloodPressureCategory.prehypertension;
    if (systolic >= 90 && diastolic >= 60) return BloodPressureCategory.optimal;
    return BloodPressureCategory.low;
  }

  BmiCategory? get bmiCategory {
    if (bmi == null || bmi! <= 0) return null;
    if (bmi! < 18.5) return BmiCategory.underweight;
    if (bmi! <= 24.9) return BmiCategory.normal;
    if (bmi! <= 29.9) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  String get bpLabel => '$systolic/$diastolic mmHg';

  Color get statusColor {
    switch (healthStatus) {
      case 'danger':
        return const Color(0xFFDC2626);
      case 'warning':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF0D9488);
    }
  }

  factory HealthVital.fromJson(Map<String, dynamic> json) {
    return HealthVital(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? json['patient_id'] ?? '').toString(),
      appointmentId: json['appointmentId'] != null ? json['appointmentId'].toString() : (json['appointment_id']?.toString()),
      systolic: json['systolic'] is int ? json['systolic'] as int : (int.tryParse(json['systolic'].toString()) ?? 120),
      diastolic: json['diastolic'] is int ? json['diastolic'] as int : (int.tryParse(json['diastolic'].toString()) ?? 80),
      heartRate: json['heartRate'] != null ? int.tryParse(json['heartRate'].toString()) : (json['heart_rate'] != null ? int.tryParse(json['heart_rate'].toString()) : null),
      bloodSugar: json['bloodSugar'] != null ? double.tryParse(json['bloodSugar'].toString()) : (json['blood_sugar'] != null ? double.tryParse(json['blood_sugar'].toString()) : null),
      bloodSugarCondition: (json['bloodSugarCondition'] ?? json['blood_sugar_condition'] ?? 'fasting').toString(),
      weight: json['weight'] != null ? double.tryParse(json['weight'].toString()) : null,
      height: json['height'] != null ? double.tryParse(json['height'].toString()) : null,
      bmi: json['bmi'] != null ? double.tryParse(json['bmi'].toString()) : null,
      healthStatus: (json['healthStatus'] ?? json['health_status'] ?? 'optimal').toString(),
      healthNote: (json['healthNote'] ?? json['health_note'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      recordedBy: (json['recordedBy'] ?? json['recorded_by'] ?? 'patient').toString(),
      recordedAt: json['recordedAt'] != null ? DateTime.parse(json['recordedAt'].toString()) : (json['recorded_at'] != null ? DateTime.parse(json['recorded_at'].toString()) : DateTime.now()),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'appointmentId': appointmentId,
        'systolic': systolic,
        'diastolic': diastolic,
        'heartRate': heartRate,
        'bloodSugar': bloodSugar,
        'bloodSugarCondition': bloodSugarCondition,
        'weight': weight,
        'height': height,
        'bmi': bmi,
        'healthStatus': healthStatus,
        'healthNote': healthNote,
        'note': note,
        'recordedBy': recordedBy,
        'recordedAt': recordedAt.toIso8601String(),
      };
}

class VitalsSummary {
  const VitalsSummary({
    this.latest,
    this.totalRecords = 0,
    this.avgSystolic,
    this.avgDiastolic,
    this.avgHeartRate,
    this.avgBloodSugar,
    this.avgBmi,
    this.dangerCount = 0,
    this.warningCount = 0,
  });

  final HealthVital? latest;
  final int totalRecords;
  final int? avgSystolic;
  final int? avgDiastolic;
  final int? avgHeartRate;
  final double? avgBloodSugar;
  final double? avgBmi;
  final int dangerCount;
  final int warningCount;

  factory VitalsSummary.fromJson(Map<String, dynamic> json) {
    return VitalsSummary(
      latest: json['latest'] != null ? HealthVital.fromJson(json['latest'] as Map<String, dynamic>) : null,
      totalRecords: json['totalRecords'] is int ? json['totalRecords'] as int : (json['total_records'] is int ? json['total_records'] as int : 0),
      avgSystolic: json['avgSystolic'] != null ? int.tryParse(json['avgSystolic'].toString()) : (json['avg_systolic'] != null ? int.tryParse(json['avg_systolic'].toString()) : null),
      avgDiastolic: json['avgDiastolic'] != null ? int.tryParse(json['avgDiastolic'].toString()) : (json['avg_diastolic'] != null ? int.tryParse(json['avg_diastolic'].toString()) : null),
      avgHeartRate: json['avgHeartRate'] != null ? int.tryParse(json['avgHeartRate'].toString()) : (json['avg_heart_rate'] != null ? int.tryParse(json['avg_heart_rate'].toString()) : null),
      avgBloodSugar: json['avgBloodSugar'] != null ? double.tryParse(json['avgBloodSugar'].toString()) : (json['avg_blood_sugar'] != null ? double.tryParse(json['avg_blood_sugar'].toString()) : null),
      avgBmi: json['avgBmi'] != null ? double.tryParse(json['avgBmi'].toString()) : (json['avg_bmi'] != null ? double.tryParse(json['avg_bmi'].toString()) : null),
      dangerCount: json['dangerCount'] is int ? json['dangerCount'] as int : (json['danger_count'] is int ? json['danger_count'] as int : 0),
      warningCount: json['warningCount'] is int ? json['warningCount'] as int : (json['warning_count'] is int ? json['warning_count'] as int : 0),
    );
  }
}
