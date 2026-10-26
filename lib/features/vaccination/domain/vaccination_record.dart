import 'dart:convert';
import '../../../core/utils/app_timezone.dart';

class VaccinationRecord {
  const VaccinationRecord({
    required this.id,
    required this.patientId,
    this.familyMemberId = 'fam-self',
    required this.patientName,
    required this.vaccineName,
    required this.targetDisease,
    this.doseNumber = 1,
    this.totalDoses = 3,
    required this.batchNumber,
    required this.manufacturer,
    required this.administeredDate,
    this.nextDoseDate,
    this.facilityName = 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
    this.doctorName = 'BS. Trần Thảo Linh',
    this.nurseName = 'ĐD. Lê Thị Hồng',
    this.reactionStatus = 'Bình thường, không sốt, không phản ứng phụ',
    required this.certificateCode,
    this.status = 'completed',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String familyMemberId;
  final String patientName;
  final String vaccineName;
  final String targetDisease;
  final int doseNumber;
  final int totalDoses;
  final String batchNumber;
  final String manufacturer;
  final DateTime administeredDate;
  final DateTime? nextDoseDate;
  final String facilityName;
  final String doctorName;
  final String? nurseName;
  final String reactionStatus;
  final String certificateCode;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => doseNumber >= totalDoses || nextDoseDate == null;

  int? get daysUntilNextDose {
    if (nextDoseDate == null) return null;
    final now = AppTimezone.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(nextDoseDate!.year, nextDoseDate!.month, nextDoseDate!.day);
    return target.difference(today).inDays;
  }

  bool get isDueSoon {
    final days = daysUntilNextDose;
    return days != null && days <= 7 && days >= 0;
  }

  bool get isOverdue {
    final days = daysUntilNextDose;
    return days != null && days < 0;
  }

  String get doseProgressLabel => 'Mũi $doseNumber / $totalDoses';

  double get doseProgressFraction => (doseNumber / totalDoses).clamp(0.0, 1.0);

  String get administeredDateLabel => AppTimezone.date(administeredDate);

  String? get nextDoseDateLabel => nextDoseDate != null ? AppTimezone.date(nextDoseDate!) : null;

  String get verificationQrData {
    return jsonEncode({
      'issuer': 'SMART_HOSPITAL_DIGITAL_HEALTH',
      'certCode': certificateCode,
      'patientName': patientName,
      'patientId': patientId,
      'vaccineName': vaccineName,
      'targetDisease': targetDisease,
      'dose': '$doseNumber/$totalDoses',
      'administeredDate': administeredDate.toIso8601String().substring(0, 10),
      'facility': facilityName,
      'status': isCompleted ? 'FULL_IMMUNIZATION' : 'IN_PROGRESS',
    });
  }

  VaccinationRecord copyWith({
    String? id,
    String? patientId,
    String? familyMemberId,
    String? patientName,
    String? vaccineName,
    String? targetDisease,
    int? doseNumber,
    int? totalDoses,
    String? batchNumber,
    String? manufacturer,
    DateTime? administeredDate,
    DateTime? nextDoseDate,
    String? facilityName,
    String? doctorName,
    String? nurseName,
    String? reactionStatus,
    String? certificateCode,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaccinationRecord(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      patientName: patientName ?? this.patientName,
      vaccineName: vaccineName ?? this.vaccineName,
      targetDisease: targetDisease ?? this.targetDisease,
      doseNumber: doseNumber ?? this.doseNumber,
      totalDoses: totalDoses ?? this.totalDoses,
      batchNumber: batchNumber ?? this.batchNumber,
      manufacturer: manufacturer ?? this.manufacturer,
      administeredDate: administeredDate ?? this.administeredDate,
      nextDoseDate: nextDoseDate ?? this.nextDoseDate,
      facilityName: facilityName ?? this.facilityName,
      doctorName: doctorName ?? this.doctorName,
      nurseName: nurseName ?? this.nurseName,
      reactionStatus: reactionStatus ?? this.reactionStatus,
      certificateCode: certificateCode ?? this.certificateCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory VaccinationRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? AppTimezone.now();
      }
      return AppTimezone.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return VaccinationRecord(
      id: (json['id'] ?? '') as String,
      patientId: (json['patientId'] ?? json['patient_id'] ?? '') as String,
      familyMemberId: (json['familyMemberId'] ?? json['family_member_id'] ?? 'fam-self') as String,
      patientName: (json['patientName'] ?? json['patient_name'] ?? '') as String,
      vaccineName: (json['vaccineName'] ?? json['vaccine_name'] ?? '') as String,
      targetDisease: (json['targetDisease'] ?? json['target_disease'] ?? '') as String,
      doseNumber: (json['doseNumber'] ?? json['dose_number'] ?? 1) as int,
      totalDoses: (json['totalDoses'] ?? json['total_doses'] ?? 3) as int,
      batchNumber: (json['batchNumber'] ?? json['batch_number'] ?? '') as String,
      manufacturer: (json['manufacturer'] ?? '') as String,
      administeredDate: parseDate(json['administeredDate'] ?? json['administered_date']),
      nextDoseDate: parseNullableDate(json['nextDoseDate'] ?? json['next_dose_date']),
      facilityName: (json['facilityName'] ?? json['facility_name'] ?? 'Bệnh viện Đa khoa Quốc tế Smart Hospital') as String,
      doctorName: (json['doctorName'] ?? json['doctor_name'] ?? 'BS. Trần Thảo Linh') as String,
      nurseName: (json['nurseName'] ?? json['nurse_name']) as String?,
      reactionStatus: (json['reactionStatus'] ?? json['reaction_status'] ?? 'Bình thường, không sốt, không phản ứng phụ') as String,
      certificateCode: (json['certificateCode'] ?? json['certificate_code'] ?? '') as String,
      status: (json['status'] ?? 'completed') as String,
      createdAt: parseNullableDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseNullableDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'family_member_id': familyMemberId,
      'patient_name': patientName,
      'vaccine_name': vaccineName,
      'target_disease': targetDisease,
      'dose_number': doseNumber,
      'total_doses': totalDoses,
      'batch_number': batchNumber,
      'manufacturer': manufacturer,
      'administered_date': administeredDate.toIso8601String().substring(0, 10),
      'next_dose_date': nextDoseDate?.toIso8601String().substring(0, 10),
      'facility_name': facilityName,
      'doctor_name': doctorName,
      'nurse_name': nurseName,
      'reaction_status': reactionStatus,
      'certificate_code': certificateCode,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class VaccineProtocolItem {
  const VaccineProtocolItem({
    required this.name,
    required this.target,
    required this.schedule,
    required this.recommendedDoses,
  });

  final String name;
  final String target;
  final String schedule;
  final int recommendedDoses;

  factory VaccineProtocolItem.fromJson(Map<String, dynamic> json) {
    return VaccineProtocolItem(
      name: (json['name'] ?? '') as String,
      target: (json['target'] ?? '') as String,
      schedule: (json['schedule'] ?? '') as String,
      recommendedDoses: (json['recommendedDoses'] ?? 1) as int,
    );
  }
}

class VaccineProtocolGroup {
  const VaccineProtocolGroup({
    required this.ageGroup,
    required this.vaccines,
  });

  final String ageGroup;
  final List<VaccineProtocolItem> vaccines;

  factory VaccineProtocolGroup.fromJson(Map<String, dynamic> json) {
    final list = (json['vaccines'] as List? ?? [])
        .map((e) => VaccineProtocolItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return VaccineProtocolGroup(
      ageGroup: (json['ageGroup'] ?? '') as String,
      vaccines: list,
    );
  }
}
