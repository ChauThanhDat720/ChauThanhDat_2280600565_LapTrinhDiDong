import 'package:flutter/foundation.dart';

import '../../../core/utils/app_timezone.dart';

enum AppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled;

  String get wireName => name.toUpperCase();
  String get label => switch (this) {
    pending => 'Chờ xác nhận',
    confirmed => 'Đã xác nhận',
    completed => 'Đã hoàn thành',
    cancelled => 'Đã hủy',
  };
  static AppointmentStatus fromJson(Object? value) =>
      switch (value.toString().toUpperCase()) {
        'CONFIRMED' => confirmed,
        'COMPLETED' => completed,
        'CANCELLED' => cancelled,
        _ => pending,
      };
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
    this.departmentId = '',
    this.status = AppointmentStatus.pending,
    this.createdAt,
    this.updatedAt,
    this.cancelledAt,
    this.cancellationReason,
  });
  final String id,
      doctorId,
      doctorName,
      specialty,
      department,
      time,
      reason,
      patientId,
      departmentId;
  final DateTime date;
  final AppointmentStatus status;
  final DateTime? createdAt, updatedAt, cancelledAt;
  final String? cancellationReason;
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
  Appointment copyWith({
    AppointmentStatus? status,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) => Appointment(
    id: id,
    doctorId: doctorId,
    doctorName: doctorName,
    specialty: specialty,
    department: department,
    date: date,
    time: time,
    reason: reason,
    patientId: patientId,
    departmentId: departmentId,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancellationReason: cancellationReason ?? this.cancellationReason,
  );
  factory Appointment.fromJson(Map<String, dynamic> j) {
    final start = AppTimezone.fromUtc(
      DateTime.parse((j['startTime'] ?? j['scheduledAt']) as String),
    );
    return Appointment(
      id: (j['appointmentId'] ?? j['id'] ?? '') as String,
      patientId: j['patientId'] as String? ?? '',
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
    );
  }
  Map<String, dynamic> toJson() => {
    'appointmentId': id,
    'doctorId': doctorId,
    'departmentId': departmentId,
    'startTime': AppTimezone.toUtc(startTime).toIso8601String(),
    'endTime': AppTimezone.toUtc(endTime).toIso8601String(),
    'reason': reason,
    'status': status.wireName,
  };
}

/// Compatibility store retained for Phase 2 screens while repositories migrate.
class AppointmentStore extends ChangeNotifier {
  AppointmentStore._();
  static final instance = AppointmentStore._();
  final List<Appointment> _appointments = [];
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<Appointment> getAppointments() => appointments;
  void addAppointment(Appointment appointment) {
    _appointments.add(appointment);
    _appointments.sort((a, b) => a.startTime.compareTo(b.startTime));
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
    notifyListeners();
  }

  void replaceAppointment(Appointment appointment) {
    final index = _appointments.indexWhere((item) => item.id == appointment.id);
    if (index < 0) return;
    _appointments[index] = appointment;
    notifyListeners();
  }

  void clearForTest() {
    _appointments.clear();
    notifyListeners();
  }
}
