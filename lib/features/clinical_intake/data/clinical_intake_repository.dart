import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/app_timezone.dart';
import '../../appointments/domain/appointment.dart';
import '../domain/clinical_intake.dart';

abstract interface class ClinicalIntakeRepository {
  Future<ClinicalIntake?> getIntake(String appointmentId);
  Future<ClinicalIntake> saveIntake(ClinicalIntake intake);
}

class ClinicalIntakeStore extends ChangeNotifier {
  ClinicalIntakeStore._();
  static final instance = ClinicalIntakeStore._();

  final Map<String, ClinicalIntake> _intakes = {};
  List<ClinicalIntake> get allIntakes => _intakes.values.toList();

  void clearForTest() {
    _intakes.clear();
    notifyListeners();
  }

  void seedIfEmpty() {
    if (_intakes.isNotEmpty) return;
    final now = AppTimezone.now();

    // Sample intake for APT-101 (Nguyen Van An with BS. Tran Thao Linh)
    final intake101 = ClinicalIntake(
      id: 'intake-APT-101',
      appointmentId: 'APT-101',
      patientId: 'BN-01',
      chiefComplaint: 'Đau tức ngực trái âm ỉ, lan ra bả vai khi đi bộ nhanh',
      painLocation: 'Ngực / Tim mạch',
      onsetDuration: '3 ngày trước',
      painLevel: 6,
      symptoms: [
        'Đau thắt ngực',
        'Khó thở khi gắng sức',
        'Hồi hộp đánh trống ngực',
      ],
      currentMedications:
          'Panadol Extra khi nhức đầu, viên uống bổ sung Omega 3',
      medicalHistory: 'Tăng huyết áp 2 năm, chưa từng phẫu thuật',
      knownAllergies: 'Dị ứng kháng sinh nhóm Penicillin (nổi mề đay ngứa)',
      notes: 'Bác sĩ kiểm tra kỹ tim mạch giúp em vì ba em có tiền sử nhồi máu cơ tim.',
      submittedAt: now.subtract(const Duration(hours: 1)),
    );

    // Sample intake for APT-103
    final intake103 = ClinicalIntake(
      id: 'intake-APT-103',
      appointmentId: 'APT-103',
      patientId: 'BN-03',
      chiefComplaint: 'Khó thở về đêm, cảm giác hụt hơi và hồi hộp',
      painLocation: 'Hô hấp & Tim mạch',
      onsetDuration: '1 tuần nay',
      painLevel: 5,
      symptoms: ['Khó thở', 'Mất ngủ', 'Hồi hộp', 'Choáng váng'],
      currentMedications: 'Hoạt huyết dưỡng não',
      medicalHistory: 'Rối loạn tiền đình nhẹ',
      knownAllergies: 'Không có tiền sử dị ứng thuốc',
      notes: 'Dạo này em hay làm việc khuya và căng thẳng.',
      submittedAt: now.subtract(const Duration(days: 1)),
    );

    _intakes[intake101.appointmentId] = intake101;
    _intakes[intake103.appointmentId] = intake103;
    notifyListeners();
  }

  ClinicalIntake? getByAppointmentId(String appointmentId) {
    seedIfEmpty();
    return _intakes[appointmentId];
  }

  void save(ClinicalIntake intake) {
    _intakes[intake.appointmentId] = intake;

    // Also update AppointmentStore so hasIntake is true
    final appt = AppointmentStore.instance.appointments
        .where((a) => a.id == intake.appointmentId)
        .firstOrNull;
    if (appt != null) {
      AppointmentStore.instance.replaceAppointment(
        appt.copyWith(hasIntake: true),
      );
    }

    notifyListeners();
  }
}

class LocalClinicalIntakeRepository implements ClinicalIntakeRepository {
  const LocalClinicalIntakeRepository();

  @override
  Future<ClinicalIntake?> getIntake(String appointmentId) async {
    return ClinicalIntakeStore.instance.getByAppointmentId(appointmentId);
  }

  @override
  Future<ClinicalIntake> saveIntake(ClinicalIntake intake) async {
    ClinicalIntakeStore.instance.save(intake);
    return intake;
  }
}

class RemoteClinicalIntakeRepository implements ClinicalIntakeRepository {
  const RemoteClinicalIntakeRepository(this._client);
  final ApiClient _client;
  @override
  Future<ClinicalIntake?> getIntake(String appointmentId) async {
    try {
      final value = await _client.get('/appointments/$appointmentId/intake');
      return ClinicalIntake.fromJson(value as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<ClinicalIntake> saveIntake(ClinicalIntake intake) async =>
      ClinicalIntake.fromJson(
        await _client.post(
          '/appointments/${intake.appointmentId}/intake',
          body: intake.toJson(),
        ) as Map<String, dynamic>,
      );
}
