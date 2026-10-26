import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../domain/medication_reminder.dart';

abstract class MedicationReminderRepository {
  Future<List<MedicationReminder>> getReminders({String? patientId, bool? isActive});
  Future<List<MedicationDoseLog>> getTodayDoses({String? patientId, String? date});
  Future<ComplianceStats> getComplianceStats({String? patientId, int days = 7});
  Future<MedicationReminder> createReminder(MedicationReminder reminder);
  Future<List<MedicationReminder>> createFromPrescription({
    required String prescription,
    String? appointmentId,
    String? patientId,
    int daysCount = 7,
  });
  Future<MedicationDoseLog> updateDoseStatus(
    String doseId,
    DoseStatus status, {
    DateTime? takenAt,
    String? note,
  });
  Future<MedicationReminder> toggleReminder(String reminderId, bool isActive);
  Future<bool> deleteReminder(String reminderId);
}

class LocalMedicationReminderRepository implements MedicationReminderRepository {
  LocalMedicationReminderRepository({List<MedicationReminder>? initialReminders}) {
    if (initialReminders != null) {
      _reminders.addAll(initialReminders);
      for (final r in initialReminders) {
        _generateLogsForReminder(r);
      }
    } else {
      _seedDefaultData();
    }
  }

  final List<MedicationReminder> _reminders = [];
  final List<MedicationDoseLog> _logs = [];

  void _seedDefaultData() {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);

    final r1 = MedicationReminder(
      id: 'REM-SEED-01',
      patientId: 'patient-1',
      medicineName: 'Paracetamol 500mg',
      dosage: '1 viên',
      instructions: 'Uống sau bữa ăn sáng và tối',
      timesPerDay: 2,
      reminderTimes: const ['08:00', '20:00'],
      startDate: now,
      daysCount: 5,
      endDate: now.add(const Duration(days: 5)),
      colorCode: '#0D9488',
      isActive: true,
    );

    final r2 = MedicationReminder(
      id: 'REM-SEED-02',
      patientId: 'patient-1',
      medicineName: 'Amoxicillin 500mg',
      dosage: '1 viên',
      instructions: 'Uống trước bữa ăn 30 phút với nhiều nước',
      timesPerDay: 2,
      reminderTimes: const ['08:00', '20:00'],
      startDate: now,
      daysCount: 7,
      endDate: now.add(const Duration(days: 7)),
      colorCode: '#2563EB',
      isActive: true,
    );

    _reminders.addAll([r1, r2]);
    _generateLogsForReminder(r1);
    _generateLogsForReminder(r2);

    // Mark the morning dose as taken for demo realism
    final morningLogIdx = _logs.indexWhere((l) => l.date == todayStr && l.time == '08:00');
    if (morningLogIdx >= 0) {
      _logs[morningLogIdx] = _logs[morningLogIdx].copyWith(
        status: DoseStatus.taken,
        takenAt: now.subtract(const Duration(hours: 1)),
      );
    }
  }

  void _generateLogsForReminder(MedicationReminder r) {
    for (int d = 0; d < r.daysCount; d++) {
      final date = r.startDate.add(Duration(days: d));
      final dateStr = date.toIso8601String().substring(0, 10);
      for (final t in r.reminderTimes) {
        final logId = 'LOG-${r.id}-$dateStr-${t.replaceAll(':', '')}';
        if (!_logs.any((l) => l.id == logId)) {
          _logs.add(
            MedicationDoseLog(
              id: logId,
              reminderId: r.id,
              medicineName: r.medicineName,
              dosage: r.dosage,
              instructions: r.instructions,
              date: dateStr,
              time: t,
              status: DoseStatus.pending,
              colorCode: r.colorCode,
            ),
          );
        }
      }
    }
  }

  @override
  Future<List<MedicationReminder>> getReminders({String? patientId, bool? isActive}) async {
    var result = List<MedicationReminder>.from(_reminders);
    if (patientId != null && patientId.isNotEmpty) {
      result = result.where((r) => r.patientId == patientId).toList();
    }
    if (isActive != null) {
      result = result.where((r) => r.isActive == isActive).toList();
    }
    return result;
  }

  @override
  Future<List<MedicationDoseLog>> getTodayDoses({String? patientId, String? date}) async {
    final targetDate = date ?? DateTime.now().toIso8601String().substring(0, 10);
    final activeIds = _reminders.where((r) => r.isActive).map((r) => r.id).toSet();

    final result = _logs
        .where((l) => l.date == targetDate && activeIds.contains(l.reminderId))
        .toList();
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  @override
  Future<ComplianceStats> getComplianceStats({String? patientId, int days = 7}) async {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final startStr = now.subtract(Duration(days: days)).toIso8601String().substring(0, 10);

    final relevant = _logs.where((l) => l.date.compareTo(startStr) >= 0 && l.date.compareTo(todayStr) <= 0).toList();
    final taken = relevant.where((l) => l.status == DoseStatus.taken).length;
    final skipped = relevant.where((l) => l.status == DoseStatus.skipped).length;
    final pending = relevant.where((l) => l.status == DoseStatus.pending).length;
    final answered = taken + skipped;
    final rate = answered > 0 ? ((taken / answered) * 100).round() : 100;

    return ComplianceStats(
      days: days,
      total: relevant.length,
      taken: taken,
      skipped: skipped,
      pending: pending,
      complianceRate: rate,
    );
  }

  @override
  Future<MedicationReminder> createReminder(MedicationReminder reminder) async {
    final id = reminder.id.isEmpty
        ? 'REM-${DateTime.now().millisecondsSinceEpoch}'
        : reminder.id;
    final updated = reminder.copyWith(id: id);
    _reminders.add(updated);
    _generateLogsForReminder(updated);
    return updated;
  }

  @override
  Future<List<MedicationReminder>> createFromPrescription({
    required String prescription,
    String? appointmentId,
    String? patientId,
    int daysCount = 7,
  }) async {
    final lines = prescription
        .split(RegExp(r'[\n;]+'))
        .map((l) => l.trim())
        .filterNotEmpty();

    final createdList = <MedicationReminder>[];
    final colors = ['#0D9488', '#2563EB', '#7C3AED', '#DB2777', '#EA580C'];
    int colorIdx = 0;
    final now = DateTime.now();

    for (final line in lines) {
      final clean = line.replaceFirst(RegExp(r'^\d+[\.\-\)]\s*'), '').trim();
      String name = clean;
      String extra = '';

      if (clean.contains(':')) {
        final p = clean.split(':');
        name = p[0].trim();
        extra = p.sublist(1).join(':').trim();
      } else if (clean.contains('(') && clean.contains(')')) {
        final m = RegExp(r'^(.*?)\((.*?)\)').firstMatch(clean);
        if (m != null) {
          name = m.group(1)!.trim();
          extra = m.group(2)!.trim();
        }
      }

      int timesPerDay = 2;
      List<String> times = ['08:00', '20:00'];
      final exLow = '$clean $extra'.toLowerCase();

      if (exLow.contains('3 lần') || exLow.contains('sáng, trưa, tối')) {
        timesPerDay = 3;
        times = ['08:00', '13:00', '20:00'];
      } else if (exLow.contains('4 lần')) {
        timesPerDay = 4;
        times = ['07:00', '12:00', '17:00', '21:00'];
      } else if (exLow.contains('1 lần')) {
        timesPerDay = 1;
        times = ['08:00'];
      }

      String dosage = '1 viên';
      final doseM = RegExp(r'(\d+\s*(?:viên|gói|ml|giọt|ống))').firstMatch(exLow);
      if (doseM != null) {
        dosage = doseM.group(1)!;
      }

      String instructions = 'Uống sau bữa ăn 30 phút';
      if (exLow.contains('trước ăn') || exLow.contains('trước bữa')) {
        instructions = 'Uống trước bữa ăn 30 phút';
      }

      final rem = MedicationReminder(
        id: 'REM-${DateTime.now().millisecondsSinceEpoch}-$colorIdx',
        patientId: patientId ?? 'patient-1',
        appointmentId: appointmentId,
        medicineName: name,
        dosage: dosage,
        instructions: instructions,
        timesPerDay: timesPerDay,
        reminderTimes: times,
        startDate: now,
        daysCount: daysCount,
        endDate: now.add(Duration(days: daysCount)),
        colorCode: colors[colorIdx % colors.length],
        isActive: true,
      );

      _reminders.add(rem);
      _generateLogsForReminder(rem);
      createdList.add(rem);
      colorIdx++;
    }

    return createdList;
  }

  @override
  Future<MedicationDoseLog> updateDoseStatus(
    String doseId,
    DoseStatus status, {
    DateTime? takenAt,
    String? note,
  }) async {
    final idx = _logs.indexWhere((l) => l.id == doseId);
    if (idx < 0) {
      throw Exception('Không tìm thấy liều uống $doseId');
    }
    final updated = _logs[idx].copyWith(
      status: status,
      takenAt: status == DoseStatus.taken ? (takenAt ?? DateTime.now()) : null,
      note: note,
    );
    _logs[idx] = updated;
    return updated;
  }

  @override
  Future<MedicationReminder> toggleReminder(String reminderId, bool isActive) async {
    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) throw Exception('Không tìm thấy lời nhắc $reminderId');
    final updated = _reminders[idx].copyWith(isActive: isActive);
    _reminders[idx] = updated;
    return updated;
  }

  @override
  Future<bool> deleteReminder(String reminderId) async {
    _reminders.removeWhere((r) => r.id == reminderId);
    _logs.removeWhere((l) => l.reminderId == reminderId);
    return true;
  }
}

extension _IterableExtension<T> on Iterable<T> {
  Iterable<T> filterNotEmpty() => where((e) => e != null && e.toString().trim().isNotEmpty);
}

class RemoteMedicationReminderRepository implements MedicationReminderRepository {
  const RemoteMedicationReminderRepository([this._client]);

  final ApiClient? _client;
  static final _fallback = LocalMedicationReminderRepository();

  @override
  Future<List<MedicationReminder>> getReminders({String? patientId, bool? isActive}) async {
    try {
      if (_client == null) return await _fallback.getReminders(patientId: patientId, isActive: isActive);
      final query = <String, String>{};
      if (patientId != null) query['patientId'] = patientId;
      if (isActive != null) query['isActive'] = isActive.toString();
      final res = await _client.get('/medication-reminders', query: query);
      if (res is Map<String, dynamic> && res['reminders'] is List) {
        return (res['reminders'] as List)
            .map((e) => MedicationReminder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return await _fallback.getReminders(patientId: patientId, isActive: isActive);
    } catch (_) {
      return await _fallback.getReminders(patientId: patientId, isActive: isActive);
    }
  }

  @override
  Future<List<MedicationDoseLog>> getTodayDoses({String? patientId, String? date}) async {
    try {
      if (_client == null) return await _fallback.getTodayDoses(patientId: patientId, date: date);
      final query = <String, String>{};
      if (patientId != null) query['patientId'] = patientId;
      if (date != null) query['date'] = date;
      final res = await _client.get('/medication-reminders/today', query: query);
      if (res is Map<String, dynamic> && res['doses'] is List) {
        return (res['doses'] as List)
            .map((e) => MedicationDoseLog.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return await _fallback.getTodayDoses(patientId: patientId, date: date);
    } catch (_) {
      return await _fallback.getTodayDoses(patientId: patientId, date: date);
    }
  }

  @override
  Future<ComplianceStats> getComplianceStats({String? patientId, int days = 7}) async {
    try {
      if (_client == null) return await _fallback.getComplianceStats(patientId: patientId, days: days);
      final query = <String, String>{'days': days.toString()};
      if (patientId != null) query['patientId'] = patientId;
      final res = await _client.get('/medication-reminders/today', query: query);
      if (res is Map<String, dynamic> && res['stats'] is Map<String, dynamic>) {
        return ComplianceStats.fromJson(res['stats'] as Map<String, dynamic>);
      }
      return await _fallback.getComplianceStats(patientId: patientId, days: days);
    } catch (_) {
      return await _fallback.getComplianceStats(patientId: patientId, days: days);
    }
  }

  @override
  Future<MedicationReminder> createReminder(MedicationReminder reminder) async {
    try {
      if (_client == null) return await _fallback.createReminder(reminder);
      final res = await _client.post('/medication-reminders', body: jsonEncode(reminder.toJson()));
      if (res is Map<String, dynamic> && res['reminder'] != null) {
        return MedicationReminder.fromJson(res['reminder'] as Map<String, dynamic>);
      }
      return await _fallback.createReminder(reminder);
    } catch (_) {
      return await _fallback.createReminder(reminder);
    }
  }

  @override
  Future<List<MedicationReminder>> createFromPrescription({
    required String prescription,
    String? appointmentId,
    String? patientId,
    int daysCount = 7,
  }) async {
    try {
      if (_client == null) {
        return await _fallback.createFromPrescription(
          prescription: prescription,
          appointmentId: appointmentId,
          patientId: patientId,
          daysCount: daysCount,
        );
      }
      final res = await _client.post(
        '/medication-reminders/from-prescription',
        body: jsonEncode({
          'prescription': prescription,
          'appointmentId': appointmentId,
          'patientId': patientId,
          'daysCount': daysCount,
        }),
      );
      if (res is Map<String, dynamic> && res['reminders'] is List) {
        return (res['reminders'] as List)
            .map((e) => MedicationReminder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return await _fallback.createFromPrescription(
        prescription: prescription,
        appointmentId: appointmentId,
        patientId: patientId,
        daysCount: daysCount,
      );
    } catch (_) {
      return await _fallback.createFromPrescription(
        prescription: prescription,
        appointmentId: appointmentId,
        patientId: patientId,
        daysCount: daysCount,
      );
    }
  }

  @override
  Future<MedicationDoseLog> updateDoseStatus(
    String doseId,
    DoseStatus status, {
    DateTime? takenAt,
    String? note,
  }) async {
    try {
      if (_client == null) {
        return await _fallback.updateDoseStatus(doseId, status, takenAt: takenAt, note: note);
      }
      final res = await _client.post(
        '/medication-reminders/doses/$doseId',
        body: jsonEncode({
          'status': status.toServerString(),
          'takenAt': takenAt?.toIso8601String(),
          'note': note,
        }),
      );
      if (res is Map<String, dynamic> && res['dose'] != null) {
        return MedicationDoseLog.fromJson(res['dose'] as Map<String, dynamic>);
      }
      return await _fallback.updateDoseStatus(doseId, status, takenAt: takenAt, note: note);
    } catch (_) {
      return await _fallback.updateDoseStatus(doseId, status, takenAt: takenAt, note: note);
    }
  }

  @override
  Future<MedicationReminder> toggleReminder(String reminderId, bool isActive) async {
    try {
      if (_client == null) return await _fallback.toggleReminder(reminderId, isActive);
      final res = await _client.patch(
        '/medication-reminders/$reminderId/toggle',
        body: jsonEncode({'isActive': isActive}),
      );
      if (res is Map<String, dynamic> && res['reminder'] != null) {
        return MedicationReminder.fromJson(res['reminder'] as Map<String, dynamic>);
      }
      return await _fallback.toggleReminder(reminderId, isActive);
    } catch (_) {
      return await _fallback.toggleReminder(reminderId, isActive);
    }
  }

  @override
  Future<bool> deleteReminder(String reminderId) async {
    try {
      if (_client == null) return await _fallback.deleteReminder(reminderId);
      final res = await _client.delete('/medication-reminders/$reminderId');
      if (res is Map<String, dynamic> && res['success'] == true) {
        return true;
      }
      return await _fallback.deleteReminder(reminderId);
    } catch (_) {
      return await _fallback.deleteReminder(reminderId);
    }
  }
}
