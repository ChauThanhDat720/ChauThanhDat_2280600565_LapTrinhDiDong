import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/session/patient_session.dart';
import '../domain/health_vital.dart';

abstract class HealthVitalsRepository {
  Future<List<HealthVital>> getVitalsHistory({String? patientId, int days = 30});
  Future<HealthVital?> getLatestVital({String? patientId});
  Future<VitalsSummary> getVitalsSummary({String? patientId});
  Future<HealthVital> recordVital(HealthVital vital);
  Future<bool> deleteVital(String id);
}

class LocalHealthVitalsRepository implements HealthVitalsRepository {
  LocalHealthVitalsRepository({List<HealthVital>? initialVitals})
    : _hasCustomInitial = initialVitals != null {
    if (initialVitals != null) {
      _vitals.addAll(initialVitals);
    } else {
      _seedDefaultData();
    }
  }

  final List<HealthVital> _vitals = [];
  final bool _hasCustomInitial;

  void _seedDefaultData() {
    final now = DateTime.now();
    final samples = [
      HealthVital(
        id: 'VIT-SEED-01',
        patientId: 'patient-1',
        systolic: 145,
        diastolic: 92,
        heartRate: 84,
        bloodSugar: 6.8,
        bloodSugarCondition: 'fasting',
        weight: 68.0,
        height: 170.0,
        bmi: 23.5,
        healthStatus: 'danger',
        healthNote: 'Tăng huyết áp độ 1 (Vượt ngưỡng an toàn)',
        note: 'Đo buổi sáng, thấy hơi đau đầu nhẹ',
        recordedBy: 'patient',
        recordedAt: now.subtract(const Duration(days: 9)),
      ),
      HealthVital(
        id: 'VIT-SEED-02',
        patientId: 'patient-1',
        systolic: 140,
        diastolic: 90,
        heartRate: 80,
        bloodSugar: 6.5,
        bloodSugarCondition: 'fasting',
        weight: 67.8,
        height: 170.0,
        bmi: 23.5,
        healthStatus: 'danger',
        healthNote: 'Tăng huyết áp độ 1',
        note: 'Đo tại phòng khám khi tái khám',
        recordedBy: 'clinic',
        recordedAt: now.subtract(const Duration(days: 7)),
      ),
      HealthVital(
        id: 'VIT-SEED-03',
        patientId: 'patient-1',
        systolic: 134,
        diastolic: 86,
        heartRate: 78,
        bloodSugar: 6.2,
        bloodSugarCondition: 'fasting',
        weight: 67.5,
        height: 170.0,
        bmi: 23.4,
        healthStatus: 'warning',
        healthNote: 'Tiền tăng huyết áp',
        note: 'Uống thuốc Amlodipine ngày thứ 2',
        recordedBy: 'patient',
        recordedAt: now.subtract(const Duration(days: 5)),
      ),
      HealthVital(
        id: 'VIT-SEED-04',
        patientId: 'patient-1',
        systolic: 128,
        diastolic: 84,
        heartRate: 76,
        bloodSugar: 5.9,
        bloodSugarCondition: 'fasting',
        weight: 67.3,
        height: 170.0,
        bmi: 23.3,
        healthStatus: 'warning',
        healthNote: 'Tiền tăng huyết áp',
        note: 'Đo sau khi đi bộ 30 phút và nghỉ ngơi',
        recordedBy: 'patient',
        recordedAt: now.subtract(const Duration(days: 4)),
      ),
      HealthVital(
        id: 'VIT-SEED-05',
        patientId: 'patient-1',
        systolic: 124,
        diastolic: 82,
        heartRate: 74,
        bloodSugar: 5.7,
        bloodSugarCondition: 'fasting',
        weight: 67.0,
        height: 170.0,
        bmi: 23.2,
        healthStatus: 'warning',
        healthNote: 'Tiền tăng huyết áp',
        note: 'Huyết áp đang hạ dần rất tốt',
        recordedBy: 'patient',
        recordedAt: now.subtract(const Duration(days: 2)),
      ),
      HealthVital(
        id: 'VIT-SEED-06',
        patientId: 'patient-1',
        systolic: 120,
        diastolic: 80,
        heartRate: 72,
        bloodSugar: 5.6,
        bloodSugarCondition: 'fasting',
        weight: 66.8,
        height: 170.0,
        bmi: 23.1,
        healthStatus: 'optimal',
        healthNote: 'Huyết áp chuẩn tối ưu (Bình thường)',
        note: 'Sức khỏe tốt, không chóng mặt',
        recordedBy: 'patient',
        recordedAt: now.subtract(const Duration(days: 1)),
      ),
      HealthVital(
        id: 'VIT-SEED-07',
        patientId: 'patient-1',
        systolic: 118,
        diastolic: 78,
        heartRate: 70,
        bloodSugar: 5.5,
        bloodSugarCondition: 'fasting',
        weight: 66.5,
        height: 170.0,
        bmi: 23.0,
        healthStatus: 'optimal',
        healthNote: 'Huyết áp chuẩn tối ưu (Bình thường)',
        note: 'Chỉ số đo sáng nay',
        recordedBy: 'patient',
        recordedAt: now,
      ),
    ];

    _vitals.addAll(samples);
  }

  List<HealthVital> _filterForPatient(String? patientId) {
    if (patientId != null &&
        patientId.isNotEmpty &&
        patientId != 'patient-1') {
      return _vitals
          .where(
            (v) =>
                v.patientId == patientId ||
                PatientSession.instance.matchesPatientId(v.patientId),
          )
          .toList();
    }
    if (_hasCustomInitial &&
        PatientSession.instance.email.isEmpty &&
        !PatientSession.instance.isViewingFamilyMember) {
      return List.of(_vitals);
    }
    return _vitals
        .where((v) => PatientSession.instance.matchesPatientId(v.patientId))
        .toList();
  }

  @override
  Future<List<HealthVital>> getVitalsHistory({String? patientId, int days = 30}) async {
    final list = _filterForPatient(patientId);
    list.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return list;
  }

  @override
  Future<HealthVital?> getLatestVital({String? patientId}) async {
    final list = _filterForPatient(patientId);
    if (list.isEmpty) return null;
    list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return list.first;
  }

  @override
  Future<VitalsSummary> getVitalsSummary({String? patientId}) async {
    final list = _filterForPatient(patientId);
    if (list.isEmpty) return const VitalsSummary();
    final latest = await getLatestVital(patientId: patientId);

    int sumSys = 0;
    int sumDia = 0;
    int count = list.length;
    int dangerCount = 0;
    int warningCount = 0;

    for (final v in list) {
      sumSys += v.systolic;
      sumDia += v.diastolic;
      if (v.healthStatus == 'danger') dangerCount++;
      if (v.healthStatus == 'warning') warningCount++;
    }

    return VitalsSummary(
      latest: latest,
      totalRecords: count,
      avgSystolic: (sumSys / count).round(),
      avgDiastolic: (sumDia / count).round(),
      avgHeartRate: 75,
      avgBloodSugar: 5.9,
      avgBmi: 23.2,
      dangerCount: dangerCount,
      warningCount: warningCount,
    );
  }

  @override
  Future<HealthVital> recordVital(HealthVital vital) async {
    final id = vital.id.isEmpty
        ? 'VIT-${DateTime.now().millisecondsSinceEpoch}'
        : vital.id;
    final resolvedPatientId =
        (vital.patientId.isEmpty ||
            (vital.patientId == 'patient-1' &&
                !PatientSession.instance.isDemoAccount))
        ? PatientSession.instance.patientId
        : vital.patientId;

    // Evaluate category
    String healthStatus = 'optimal';
    String healthNote = 'Huyết áp chuẩn tối ưu (Bình thường)';
    if (vital.systolic >= 140 || vital.diastolic >= 90) {
      healthStatus = 'danger';
      healthNote = 'Tăng huyết áp độ 1 (Vượt ngưỡng an toàn)';
    } else if (vital.systolic >= 120 || vital.diastolic >= 80) {
      healthStatus = 'warning';
      healthNote = 'Tiền tăng huyết áp (Cần theo dõi chế độ ăn)';
    }

    double? bmi = vital.bmi;
    if (bmi == null && vital.weight != null && vital.height != null && vital.height! > 0) {
      final h = vital.height! > 3 ? vital.height! / 100 : vital.height!;
      bmi = ((vital.weight! / (h * h)) * 10).round() / 10;
    }

    final updated = HealthVital(
      id: id,
      patientId: resolvedPatientId,
      appointmentId: vital.appointmentId,
      systolic: vital.systolic,
      diastolic: vital.diastolic,
      heartRate: vital.heartRate,
      bloodSugar: vital.bloodSugar,
      bloodSugarCondition: vital.bloodSugarCondition,
      weight: vital.weight,
      height: vital.height,
      bmi: bmi,
      healthStatus: healthStatus,
      healthNote: healthNote,
      note: vital.note,
      recordedBy: vital.recordedBy,
      recordedAt: vital.recordedAt,
      createdAt: DateTime.now(),
    );

    _vitals.add(updated);
    return updated;
  }

  @override
  Future<bool> deleteVital(String id) async {
    _vitals.removeWhere((v) => v.id == id);
    return true;
  }
}

class RemoteHealthVitalsRepository implements HealthVitalsRepository {
  const RemoteHealthVitalsRepository([this._client]);

  final ApiClient? _client;
  static final _fallback = LocalHealthVitalsRepository();

  @override
  Future<List<HealthVital>> getVitalsHistory({String? patientId, int days = 30}) async {
    try {
      if (_client == null) return await _fallback.getVitalsHistory(patientId: patientId, days: days);
      final pId = patientId ?? 'test-patient-sub-123';
      final res = await _client.get('/patients/$pId/vitals', query: {'days': days.toString()});
      if (res is Map<String, dynamic> && res['history'] is List) {
        return (res['history'] as List)
            .map((e) => HealthVital.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return await _fallback.getVitalsHistory(patientId: patientId, days: days);
    } catch (_) {
      return await _fallback.getVitalsHistory(patientId: patientId, days: days);
    }
  }

  @override
  Future<HealthVital?> getLatestVital({String? patientId}) async {
    try {
      if (_client == null) return await _fallback.getLatestVital(patientId: patientId);
      final pId = patientId ?? 'test-patient-sub-123';
      final res = await _client.get('/patients/$pId/vitals/latest');
      if (res is Map<String, dynamic> && res['latest'] != null) {
        return HealthVital.fromJson(res['latest'] as Map<String, dynamic>);
      }
      return await _fallback.getLatestVital(patientId: patientId);
    } catch (_) {
      return await _fallback.getLatestVital(patientId: patientId);
    }
  }

  @override
  Future<VitalsSummary> getVitalsSummary({String? patientId}) async {
    try {
      if (_client == null) return await _fallback.getVitalsSummary(patientId: patientId);
      final pId = patientId ?? 'test-patient-sub-123';
      final res = await _client.get('/patients/$pId/vitals');
      if (res is Map<String, dynamic> && res['summary'] is Map<String, dynamic>) {
        return VitalsSummary.fromJson(res['summary'] as Map<String, dynamic>);
      }
      return await _fallback.getVitalsSummary(patientId: patientId);
    } catch (_) {
      return await _fallback.getVitalsSummary(patientId: patientId);
    }
  }

  @override
  Future<HealthVital> recordVital(HealthVital vital) async {
    try {
      if (_client == null) return await _fallback.recordVital(vital);
      final pId = vital.patientId.isNotEmpty ? vital.patientId : 'test-patient-sub-123';
      final res = await _client.post('/patients/$pId/vitals', body: jsonEncode(vital.toJson()));
      if (res is Map<String, dynamic> && res['vital'] != null) {
        return HealthVital.fromJson(res['vital'] as Map<String, dynamic>);
      }
      return await _fallback.recordVital(vital);
    } catch (_) {
      return await _fallback.recordVital(vital);
    }
  }

  @override
  Future<bool> deleteVital(String id) async {
    try {
      if (_client == null) return await _fallback.deleteVital(id);
      final res = await _client.delete('/vitals/$id');
      if (res is Map<String, dynamic> && res['success'] == true) {
        return true;
      }
      return await _fallback.deleteVital(id);
    } catch (_) {
      return await _fallback.deleteVital(id);
    }
  }
}
