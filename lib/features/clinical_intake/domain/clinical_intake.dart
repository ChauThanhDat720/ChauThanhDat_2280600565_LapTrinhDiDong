import 'package:flutter/material.dart';
import '../../../core/utils/app_timezone.dart';

class ClinicalIntake {
  const ClinicalIntake({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.chiefComplaint,
    this.painLocation = 'Ngực / Tim mạch',
    this.onsetDuration = '1 - 3 ngày trước',
    this.painLevel = 5,
    this.symptoms = const [],
    this.currentMedications = '',
    this.medicalHistory = '',
    this.knownAllergies = '',
    this.notes = '',
    required this.submittedAt,
  });

  final String id;
  final String appointmentId;
  final String patientId;
  final String chiefComplaint;
  final String painLocation;
  final String onsetDuration;
  final int painLevel;
  final List<String> symptoms;
  final String currentMedications;
  final String medicalHistory;
  final String knownAllergies;
  final String notes;
  final DateTime submittedAt;

  String get painSeverityLabel {
    if (painLevel <= 3) return 'Nhẹ (1-3)';
    if (painLevel <= 6) return 'Vừa phải (4-6)';
    if (painLevel <= 8) return 'Dữ dội (7-8)';
    return 'Rất dữ dội (9-10)';
  }

  String get painEmoji {
    if (painLevel <= 2) return '😊';
    if (painLevel <= 4) return '😐';
    if (painLevel <= 6) return '🙁';
    if (painLevel <= 8) return '😣';
    return '😭';
  }

  Color get painColor {
    if (painLevel <= 3) return const Color(0xFF16A34A);
    if (painLevel <= 6) return const Color(0xFFD97706);
    if (painLevel <= 8) return const Color(0xFFEA580C);
    return const Color(0xFFDC2626);
  }

  ClinicalIntake copyWith({
    String? id,
    String? appointmentId,
    String? patientId,
    String? chiefComplaint,
    String? painLocation,
    String? onsetDuration,
    int? painLevel,
    List<String>? symptoms,
    String? currentMedications,
    String? medicalHistory,
    String? knownAllergies,
    String? notes,
    DateTime? submittedAt,
  }) {
    return ClinicalIntake(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      painLocation: painLocation ?? this.painLocation,
      onsetDuration: onsetDuration ?? this.onsetDuration,
      painLevel: painLevel ?? this.painLevel,
      symptoms: symptoms ?? this.symptoms,
      currentMedications: currentMedications ?? this.currentMedications,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      knownAllergies: knownAllergies ?? this.knownAllergies,
      notes: notes ?? this.notes,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  factory ClinicalIntake.fromJson(Map<String, dynamic> json) {
    List<String> symptomsList = [];
    final rawSymptoms = json['symptoms'];
    if (rawSymptoms is List) {
      symptomsList = rawSymptoms.map((e) => e.toString()).toList();
    } else if (rawSymptoms is String && rawSymptoms.isNotEmpty) {
      symptomsList = rawSymptoms.split(', ').map((e) => e.trim()).toList();
    }

    return ClinicalIntake(
      id: (json['id'] ?? '') as String,
      appointmentId: (json['appointmentId'] ?? json['appointment_id'] ?? '') as String,
      patientId: (json['patientId'] ?? json['patient_id'] ?? '') as String,
      chiefComplaint: (json['chiefComplaint'] ?? json['chief_complaint'] ?? '') as String,
      painLocation: (json['painLocation'] ?? json['pain_location'] ?? 'Ngực / Tim mạch') as String,
      onsetDuration: (json['onsetDuration'] ?? json['onset_duration'] ?? '1 - 3 ngày trước') as String,
      painLevel: (json['painLevel'] ?? json['pain_level'] ?? 5) as int,
      symptoms: symptomsList,
      currentMedications: (json['currentMedications'] ?? json['current_medications'] ?? '') as String,
      medicalHistory: (json['medicalHistory'] ?? json['medical_history'] ?? '') as String,
      knownAllergies: (json['knownAllergies'] ?? json['known_allergies'] ?? '') as String,
      notes: (json['notes'] ?? '') as String,
      submittedAt: json['submittedAt'] != null || json['submitted_at'] != null
          ? DateTime.parse((json['submittedAt'] ?? json['submitted_at']) as String).toLocal()
          : AppTimezone.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'appointment_id': appointmentId,
        'patient_id': patientId,
        'chief_complaint': chiefComplaint,
        'pain_location': painLocation,
        'onset_duration': onsetDuration,
        'pain_level': painLevel,
        'symptoms': symptoms,
        'current_medications': currentMedications,
        'medical_history': medicalHistory,
        'known_allergies': knownAllergies,
        'notes': notes,
        'submitted_at': submittedAt.toIso8601String(),
      };
}
