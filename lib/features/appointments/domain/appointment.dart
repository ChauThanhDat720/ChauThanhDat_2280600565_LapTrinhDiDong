import 'package:flutter/foundation.dart';

abstract final class AppointmentStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const cancelled = 'cancelled';

  static String labelOf(String status) => switch (status) {
    pending => 'Chờ xác nhận',
    confirmed => 'Đã xác nhận',
    cancelled => 'Đã hủy',
    _ => 'Không xác định',
  };
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
    this.status = AppointmentStatus.pending,
  });

  final String id;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final String department;
  final DateTime date;
  final String time;
  final String reason;
  final String status;

  Appointment copyWith({String? status}) => Appointment(
    id: id,
    doctorId: doctorId,
    doctorName: doctorName,
    specialty: specialty,
    department: department,
    date: date,
    time: time,
    reason: reason,
    status: status ?? this.status,
  );

  String get dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Shared in-memory appointment controller for Phase 2.
class AppointmentStore extends ChangeNotifier {
  AppointmentStore._();
  static final instance = AppointmentStore._();

  final List<Appointment> _appointments = [];
  List<Appointment> get appointments => List.unmodifiable(_appointments);

  List<Appointment> getAppointments() => appointments;

  void addAppointment(Appointment appointment) {
    _appointments.add(appointment);
    _appointments.sort(_compareAppointments);
    notifyListeners();
  }

  void cancelAppointment(String id) {
    final index = _appointments.indexWhere(
      (appointment) => appointment.id == id,
    );
    if (index == -1) return;
    _appointments[index] = _appointments[index].copyWith(
      status: AppointmentStatus.cancelled,
    );
    notifyListeners();
  }

  int _compareAppointments(Appointment a, Appointment b) {
    final dateComparison = a.date.compareTo(b.date);
    return dateComparison != 0 ? dateComparison : a.time.compareTo(b.time);
  }
}
