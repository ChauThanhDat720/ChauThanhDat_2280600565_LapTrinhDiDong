import '../../../core/session/patient_session.dart';
import '../../../core/utils/app_timezone.dart';
import '../../../core/network/api_client.dart';
import '../../doctors/domain/doctor.dart';
import '../domain/appointment.dart';
import '../domain/hospital_navigation.dart';

abstract interface class AppointmentRepository {
  Future<List<AppointmentSlot>> getAvailableSlots(
    String doctorId,
    DateTime selectedDate,
  );
  Future<Appointment> createAppointment(Appointment appointment);
  Future<List<Appointment>> getAppointments();
  Future<List<Appointment>> getMyAppointments();
  Future<Appointment?> getAppointmentById(String id);
  Future<Appointment> cancelAppointment(String id, {String? reason});
  Future<List<Appointment>> getDoctorAppointments({
    String? doctorId,
    DateTime? date,
  });
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status, {
    String? note,
    String? diagnosis,
    String? prescription,
    DateTime? followUpDate,
  });
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  });
  Future<Appointment> checkinAppointment(String id, {String? roomNumber});
}

class LocalAppointmentRepository implements AppointmentRepository {
  const LocalAppointmentRepository();
  static Future<void> _serial = Future.value();
  static const _slotDuration = Duration(minutes: 30);
  static final Set<String> _doctorDaysOff = {};

  static void resetForTest() {
    AppointmentStore.instance.clearForTest();
    _doctorDaysOff.clear();
    _serial = Future.value();
  }

  static void setDoctorDayOffForTest(String doctorId, DateTime day) =>
      _doctorDaysOff.add(_dayKey(doctorId, day));
  static String _dayKey(String doctorId, DateTime day) =>
      '$doctorId-${day.year}-${day.month}-${day.day}';

  @override
  Future<List<AppointmentSlot>> getAvailableSlots(
    String doctorId,
    DateTime selectedDate,
  ) async {
    if (!_doctorExists(doctorId)) return const [];
    final day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    if (_doctorDaysOff.contains(_dayKey(doctorId, day))) return const [];
    final starts = <DateTime>[
      for (var hour = 8; hour <= 11; hour++)
        for (var minute = 0; minute < 60; minute += 30)
          if (!(hour == 11 && minute == 30))
            DateTime(day.year, day.month, day.day, hour, minute),
      for (var hour = 13; hour <= 16; hour++)
        for (var minute = 0; minute < 60; minute += 30)
          DateTime(day.year, day.month, day.day, hour, minute),
    ];
    final now = DateTime.now();
    return starts
        .map((start) {
          final occupied = AppointmentStore.instance.appointments.any(
            (item) =>
                item.doctorId == doctorId &&
                item.startTime == start &&
                (item.status == AppointmentStatus.pending ||
                    item.status == AppointmentStatus.confirmed),
          );
          final past = !start.isAfter(now);
          return AppointmentSlot(
            startTime: start,
            endTime: start.add(_slotDuration),
            isAvailable: !past && !occupied,
            unavailableReason: past
                ? 'Khung giờ đã qua'
                : occupied
                ? 'Khung giờ này đã được đặt.'
                : null,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Appointment> createAppointment(Appointment appointment) {
    final operation = _serial.then((_) async {
      if (!_doctorExists(appointment.doctorId)) {
        throw StateError('Không tìm thấy bác sĩ.');
      }
      if (appointment.reason.trim().isEmpty ||
          appointment.reason.trim().length > 500) {
        throw StateError('Lý do khám không hợp lệ.');
      }
      final slots = await getAvailableSlots(
        appointment.doctorId,
        appointment.date,
      );
      final slot = slots
          .where((item) => item.startTime == appointment.startTime)
          .firstOrNull;
      if (slot == null) {
        throw StateError('Khung giờ không thuộc lịch làm việc.');
      }
      if (!slot.isAvailable) {
        throw StateError(
          slot.unavailableReason ?? 'Khung giờ này đã được đặt.',
        );
      }
      final now = DateTime.now();
      final currentPatientId = PatientSession.instance.patientId;
      final currentPatientName = PatientSession.instance.email.isNotEmpty
          ? PatientSession.instance.name
          : 'Nguyễn Văn An (BN-01)';
      final saved = Appointment(
        id: appointment.id.isEmpty
            ? 'local-${now.microsecondsSinceEpoch}'
            : appointment.id,
        patientId: currentPatientId,
        patientName: appointment.patientName.isNotEmpty
            ? appointment.patientName
            : currentPatientName,
        doctorId: appointment.doctorId,
        doctorName: appointment.doctorName,
        specialty: appointment.specialty,
        department: appointment.department,
        departmentId: appointment.departmentId,
        date: appointment.date,
        time: appointment.time,
        reason: appointment.reason.trim(),
        status: appointment.status,
        createdAt: now,
        updatedAt: now,
        isFollowUp: appointment.isFollowUp,
        parentAppointmentId: appointment.parentAppointmentId,
      );
      AppointmentStore.instance.addAppointment(saved);
      return saved;
    });
    _serial = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  @override
  Future<List<Appointment>> getAppointments() => getMyAppointments();
  @override
  Future<List<Appointment>> getMyAppointments() async => List.unmodifiable(
    AppointmentStore.instance.appointments.where(
      (item) => PatientSession.instance.matchesPatientId(item.patientId),
    ),
  );
  @override
  Future<Appointment?> getAppointmentById(String id) async => AppointmentStore
      .instance
      .appointments
      .where(
        (item) =>
            item.id == id &&
            PatientSession.instance.matchesPatientId(item.patientId),
      )
      .firstOrNull;
  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) {
    final operation = _serial.then((_) async {
      final item = await getAppointmentById(id);
      if (item == null) {
        throw StateError('Không tìm thấy lịch khám.');
      }
      if (item.status == AppointmentStatus.completed) {
        throw StateError('Không thể hủy lịch đã hoàn thành.');
      }
      if (item.status == AppointmentStatus.cancelled) {
        throw StateError('Lịch khám đã được hủy.');
      }
      final updated = item.copyWith(
        status: AppointmentStatus.cancelled,
        updatedAt: DateTime.now(),
        cancelledAt: DateTime.now(),
        cancellationReason: reason,
      );
      AppointmentStore.instance.replaceAppointment(updated);
      return updated;
    });
    _serial = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  @override
  Future<List<Appointment>> getDoctorAppointments({
    String? doctorId,
    DateTime? date,
  }) async {
    final all = AppointmentStore.instance.appointments;
    return List.unmodifiable(
      all.where((item) {
        if (doctorId != null && item.doctorId != doctorId) return false;
        if (date != null &&
            (item.date.year != date.year ||
                item.date.month != date.month ||
                item.date.day != date.day)) {
          return false;
        }
        return true;
      }),
    );
  }

  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status, {
    String? note,
    String? diagnosis,
    String? prescription,
    DateTime? followUpDate,
  }) {
    final operation = _serial.then((_) async {
      final index = AppointmentStore.instance.appointments.indexWhere(
        (item) => item.id == id,
      );
      if (index < 0) {
        throw StateError('Không tìm thấy lịch khám.');
      }
      final current = AppointmentStore.instance.appointments[index];
      final now = DateTime.now();
      final updated = current.copyWith(
        status: status,
        updatedAt: now,
        statusNote: note,
        diagnosis: diagnosis,
        prescription: prescription,
        cancelledAt: status == AppointmentStatus.cancelled ? now : null,
        cancellationReason: status == AppointmentStatus.cancelled ? note : null,
        followUpDate: followUpDate ?? current.followUpDate,
      );
      AppointmentStore.instance.replaceAppointment(updated);
      return updated;
    });
    _serial = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async {
    final operation = _serial.then<Appointment>((_) async {
      final index = AppointmentStore.instance.appointments.indexWhere(
        (element) => element.id == id,
      );
      if (index == -1) {
        throw StateError('Appointment $id not found');
      }
      final current = AppointmentStore.instance.appointments[index];
      final updated = current.copyWith(
        rating: rating,
        reviewNote: reviewNote,
        reviewedAt: DateTime.now(),
      );
      AppointmentStore.instance.replaceAppointment(updated);
      return updated;
    });
    _serial = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) {
    final operation = _serial.then((_) async {
      final index = AppointmentStore.instance.appointments.indexWhere(
        (a) => a.id == id,
      );
      if (index < 0) {
        throw StateError('Không tìm thấy lịch khám.');
      }
      final current = AppointmentStore.instance.appointments[index];
      if (current.status == AppointmentStatus.checkedIn) return current;

      final doctorAppts = AppointmentStore.instance.appointments
          .where((a) => a.doctorId == current.doctorId && a.queueNumber != null)
          .toList();
      final nextQueue = doctorAppts.length + 1;
      final updated = current.copyWith(
        status: AppointmentStatus.checkedIn,
        queueNumber: nextQueue,
        checkedInAt: DateTime.now(),
        roomNumber:
            roomNumber ??
            current.roomNumber ??
            HospitalNavigationResolver.getDoctorClinicRoom(
              current.doctorId,
              department: current.department,
            ),
        updatedAt: DateTime.now(),
      );
      AppointmentStore.instance.replaceAppointment(updated);
      return updated;
    });
    _serial = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  bool _doctorExists(String id) => doctors.any((doctor) => doctor.id == id);
}

class RemoteAppointmentRepository implements AppointmentRepository {
  const RemoteAppointmentRepository(this._client);
  final ApiClient _client;
  @override
  Future<List<AppointmentSlot>> getAvailableSlots(
    String doctorId,
    DateTime date,
  ) async {
    final result = await _client.get(
      '/doctors/$doctorId/availability',
      query: {'date': date.toIso8601String().substring(0, 10)},
    );
    final items = result is Map<String, dynamic>
        ? result['items'] ?? result['slots']
        : result;
    return (items as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AppointmentSlot(
            startTime: AppTimezone.fromUtc(
              DateTime.parse(item['startTime'] as String),
            ),
            endTime: AppTimezone.fromUtc(
              DateTime.parse(item['endTime'] as String),
            ),
            isAvailable: item['isAvailable'] == true,
            unavailableReason: item['unavailableReason'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<Appointment> createAppointment(Appointment appointment) async =>
      Appointment.fromJson(
        await _client.post('/appointments', body: appointment.toJson())
            as Map<String, dynamic>,
      );
  @override
  Future<List<Appointment>> getAppointments() => getMyAppointments();
  @override
  Future<List<Appointment>> getMyAppointments() async =>
      _items(await _client.get('/appointments'));
  @override
  Future<Appointment?> getAppointmentById(String id) async {
    final result = await _client.get('/appointments/$id');
    return result is Map<String, dynamic> ? Appointment.fromJson(result) : null;
  }

  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) async =>
      Appointment.fromJson(
        await _client.patch(
          '/appointments/$id/cancel',
          body: {'reason': reason},
        ) as Map<String, dynamic>,
      );

  @override
  Future<List<Appointment>> getDoctorAppointments({
    String? doctorId,
    DateTime? date,
  }) async {
    final query = <String, String>{};
    if (date != null) query['date'] = date.toIso8601String().substring(0, 10);
    final result = await _client.get('/doctors/me/appointments', query: query);
    final items = result is Map<String, dynamic> ? result['items'] : result;
    return (items as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Appointment.fromJson)
        .toList();
  }

  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status, {
    String? note,
    String? diagnosis,
    String? prescription,
    DateTime? followUpDate,
  }) async {
    final result = await _client.patch(
      '/appointments/$id/status',
      body: {
        'status': status.name,
        'note': ?note,
        'diagnosis': ?diagnosis,
        'prescription': ?prescription,
        'followUpDate': ?followUpDate?.toIso8601String(),
      },
    );
    return Appointment.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async {
    final result = await _client.patch(
      '/appointments/$id/rating',
      body: {'rating': rating, 'reviewNote': ?reviewNote},
    );
    return Appointment.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<Appointment> checkinAppointment(
    String id, {
    String? roomNumber,
  }) async {
    final result = await _client.post(
      '/appointments/$id/checkin',
      body: {'roomNumber': ?roomNumber},
    );
    return Appointment.fromJson(result as Map<String, dynamic>);
  }

  List<Appointment> _items(dynamic result) {
    final items = result is Map<String, dynamic> ? result['items'] : result;
    return (items as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Appointment.fromJson)
        .toList();
  }
}
