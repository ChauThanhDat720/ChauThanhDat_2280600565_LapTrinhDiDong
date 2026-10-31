import 'package:flutter/foundation.dart';

import '../../../core/storage/local_json_storage.dart';
import '../../../core/utils/app_timezone.dart';
import 'visit_journey.dart';

enum AppointmentStatus {
  pending,
  confirmed,
  checkedIn,
  inProgress,
  completed,
  cancelled;

  String get wireName => switch (this) {
    checkedIn => 'CHECKED_IN',
    inProgress => 'IN_PROGRESS',
    _ => name.toUpperCase(),
  };

  String get label => switch (this) {
    pending => 'Chờ xác nhận',
    confirmed => 'Đã xác nhận',
    checkedIn => 'Đã tiếp đón (Đang chờ)',
    inProgress => 'Đang khám',
    completed => 'Đã hoàn thành',
    cancelled => 'Đã hủy',
  };

  String get title => label;

  static AppointmentStatus fromJson(Object? value) =>
      switch (value.toString().toUpperCase()) {
        'CONFIRMED' => confirmed,
        'CHECKED_IN' => checkedIn,
        'IN_PROGRESS' => inProgress,
        'COMPLETED' => completed,
        'CANCELLED' => cancelled,
        _ => pending,
      };

  static AppointmentStatus fromWire(String value) => fromJson(value);
}

class AppointmentSlot {
  const AppointmentSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.unavailableReason,
  });

  final DateTime startTime;
  final DateTime endTime;
  final bool isAvailable;
  final String? unavailableReason;

  String get label =>
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
}

class Appointment {
  const Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.department,
    required this.date,
    required this.time,
    required this.reason,
    this.patientId = '',
    this.patientName = 'Bệnh nhân',
    this.departmentId = '',
    this.status = AppointmentStatus.pending,
    this.createdAt,
    this.updatedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.diagnosis,
    this.prescription,
    this.statusNote,
    this.rating,
    this.reviewNote,
    this.reviewedAt,
    this.queueNumber,
    this.checkedInAt,
    this.roomNumber,
    this.followUpDate,
    this.isFollowUp = false,
    this.parentAppointmentId,
    this.hasIntake = false,
    this.journey,
  });

  final String id,
      doctorId,
      doctorName,
      specialty,
      department,
      time,
      reason,
      patientId,
      patientName,
      departmentId;
  final DateTime date;
  final AppointmentStatus status;
  final DateTime? createdAt,
      updatedAt,
      cancelledAt,
      reviewedAt,
      checkedInAt,
      followUpDate;
  final String? cancellationReason,
      diagnosis,
      prescription,
      statusNote,
      reviewNote,
      roomNumber;
  final int? rating, queueNumber;
  final bool isFollowUp;
  final String? parentAppointmentId;
  final bool hasIntake;
  final VisitJourney? journey;

  String get appointmentId => id;
  DateTime get startTime => DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(time.split(':')[0]),
    int.parse(time.split(':')[1]),
  );
  DateTime get endTime => startTime.add(const Duration(minutes: 30));
  String get dateLabel => AppTimezone.date(date);
  String? get followUpDateLabel =>
      followUpDate != null ? AppTimezone.date(followUpDate!) : null;

  bool get hasActiveFollowUp =>
      status == AppointmentStatus.completed && followUpDate != null;

  int? get followUpDaysRemaining {
    if (followUpDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      followUpDate!.year,
      followUpDate!.month,
      followUpDate!.day,
    );
    return target.difference(today).inDays;
  }

  Appointment copyWith({
    AppointmentStatus? status,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? patientId,
    String? patientName,
    String? diagnosis,
    String? prescription,
    String? statusNote,
    int? rating,
    String? reviewNote,
    DateTime? reviewedAt,
    int? queueNumber,
    DateTime? checkedInAt,
    String? roomNumber,
    DateTime? followUpDate,
    bool? isFollowUp,
    String? parentAppointmentId,
    bool? hasIntake,
    VisitJourney? journey,
  }) => Appointment(
    id: id,
    doctorId: doctorId,
    doctorName: doctorName,
    specialty: specialty,
    department: department,
    date: date,
    time: time,
    reason: reason,
    patientId: patientId ?? this.patientId,
    patientName: patientName ?? this.patientName,
    departmentId: departmentId,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancellationReason: cancellationReason ?? this.cancellationReason,
    diagnosis: diagnosis ?? this.diagnosis,
    prescription: prescription ?? this.prescription,
    statusNote: statusNote ?? this.statusNote,
    rating: rating ?? this.rating,
    reviewNote: reviewNote ?? this.reviewNote,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    queueNumber: queueNumber ?? this.queueNumber,
    checkedInAt: checkedInAt ?? this.checkedInAt,
    roomNumber: roomNumber ?? this.roomNumber,
    followUpDate: followUpDate ?? this.followUpDate,
    isFollowUp: isFollowUp ?? this.isFollowUp,
    parentAppointmentId: parentAppointmentId ?? this.parentAppointmentId,
    hasIntake: hasIntake ?? this.hasIntake,
    journey: journey ?? this.journey,
  );

  factory Appointment.fromJson(Map<String, dynamic> j) {
    final start = AppTimezone.fromUtc(
      DateTime.parse((j['startTime'] ?? j['scheduledAt']) as String),
    );
    return Appointment(
      id: (j['appointmentId'] ?? j['id'] ?? '') as String,
      patientId: j['patientId'] as String? ?? '',
      patientName: j['patientName'] as String? ?? 'Bệnh nhân',
      doctorId: j['doctorId'] as String? ?? '',
      doctorName: j['doctorName'] as String? ?? '',
      specialty: j['specialty'] as String? ?? '',
      department: (j['departmentName'] ?? j['department'] ?? '') as String,
      departmentId: j['departmentId'] as String? ?? '',
      date: start,
      time:
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      reason: j['reason'] as String? ?? '',
      status: AppointmentStatus.fromJson(j['status']),
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      cancelledAt: DateTime.tryParse(j['cancelledAt'] as String? ?? ''),
      cancellationReason: j['cancellationReason'] as String?,
      diagnosis: j['diagnosis'] as String?,
      prescription: j['prescription'] as String?,
      statusNote: j['statusNote'] as String?,
      rating: j['rating'] as int?,
      reviewNote: j['reviewNote'] as String?,
      reviewedAt: DateTime.tryParse(j['reviewedAt'] as String? ?? ''),
      queueNumber: (j['queueNumber'] ?? j['queue_number']) as int?,
      checkedInAt: DateTime.tryParse(
        (j['checkedInAt'] ?? j['checked_in_at']) as String? ?? '',
      ),
      roomNumber: (j['roomNumber'] ?? j['room_number']) as String?,
      followUpDate: DateTime.tryParse(
        j['followUpDate'] as String? ?? j['follow_up_date'] as String? ?? '',
      ),
      isFollowUp: (j['isFollowUp'] ?? j['is_follow_up']) as bool? ?? false,
      parentAppointmentId:
          (j['parentAppointmentId'] ?? j['parent_appointment_id']) as String?,
      hasIntake: (j['hasIntake'] ?? j['has_intake']) as bool? ?? false,
      journey: j['journey'] is Map<String, dynamic>
          ? VisitJourney.fromJson(j['journey'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'appointmentId': id,
    'patientId': patientId,
    'doctorId': doctorId,
    'departmentId': departmentId,
    'patientName': patientName,
    'startTime': AppTimezone.toUtc(startTime).toIso8601String(),
    'endTime': AppTimezone.toUtc(endTime).toIso8601String(),
    'reason': reason,
    'status': status.wireName,
    'diagnosis': diagnosis,
    'prescription': prescription,
    'statusNote': statusNote,
    'rating': rating,
    'reviewNote': reviewNote,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'queueNumber': queueNumber,
    'checkedInAt': checkedInAt?.toIso8601String(),
    'roomNumber': roomNumber,
    'follow_up_date': followUpDate?.toIso8601String(),
    'is_follow_up': isFollowUp,
    'parent_appointment_id': parentAppointmentId,
    'has_intake': hasIntake,
    if (journey != null) 'journey': journey!.toJson(),
  };
}

/// Compatibility store retained for Phase 2 screens while repositories migrate.
class AppointmentStore extends ChangeNotifier {
  AppointmentStore._() {
    init();
  }
  static final instance = AppointmentStore._();
  final List<Appointment> _appointments = [];
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<Appointment> getAppointments() => appointments;

  static const _storageKey = 'local_stored_appointments_v1';
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final data = await LocalJsonStorage.read(_storageKey);
      if (data != null && data.isNotEmpty) {
        for (final item in data) {
          final apt = Appointment.fromJson(item);
          if (!_appointments.any((a) => a.id == apt.id)) {
            _appointments.add(apt);
          }
        }
        _appointments.sort((a, b) => a.startTime.compareTo(b.startTime));
        notifyListeners();
      }
    } catch (_) {}
  }

  void _persist() {
    try {
      LocalJsonStorage.write(
        _storageKey,
        _appointments.map((a) => a.toJson()).toList(),
      );
    } catch (_) {}
  }

  void addAppointment(Appointment appointment) {
    _appointments.removeWhere((item) => item.id == appointment.id);
    _appointments.add(appointment);
    _appointments.sort((a, b) => a.startTime.compareTo(b.startTime));
    _persist();
    notifyListeners();
  }

  void cancelAppointment(String id) {
    final index = _appointments.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _appointments[index] = _appointments[index].copyWith(
      status: AppointmentStatus.cancelled,
      cancelledAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _persist();
    notifyListeners();
  }

  void replaceAppointment(Appointment appointment) {
    final index = _appointments.indexWhere((item) => item.id == appointment.id);
    if (index < 0) {
      _appointments.add(appointment);
    } else {
      _appointments[index] = appointment;
    }
    _persist();
    notifyListeners();
  }

  void clearForTest() {
    _appointments.clear();
    _initialized = false;
    notifyListeners();
  }
}
