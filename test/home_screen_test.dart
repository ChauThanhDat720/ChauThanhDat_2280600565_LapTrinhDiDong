import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/theme/app_theme.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/home/presentation/home_screen.dart';

class _FakeHomeRepo implements AppointmentRepository {
  _FakeHomeRepo(this.items);
  final List<Appointment> items;

  @override
  Future<List<Appointment>> getMyAppointments() async => items;

  @override
  Future<List<Appointment>> getAppointments() => getMyAppointments();

  @override
  Future<List<AppointmentSlot>> getAvailableSlots(String doctorId, DateTime date) async => [];

  @override
  Future<Appointment> createAppointment(Appointment appointment) async => appointment;

  @override
  Future<Appointment?> getAppointmentById(String id) async =>
      items.where((i) => i.id == id).firstOrNull;

  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) async =>
      items.first.copyWith(status: AppointmentStatus.cancelled);

  @override
  Future<List<Appointment>> getDoctorAppointments({
    String? doctorId,
    DateTime? date,
    AppointmentStatus? status,
  }) async => items;

  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status, {
    String? note,
    String? diagnosis,
    String? prescription,
    DateTime? followUpDate,
  }) async => items.first.copyWith(
        status: status,
        diagnosis: diagnosis,
        prescription: prescription,
      );

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async => items.first.copyWith(
        rating: rating,
        reviewNote: reviewNote,
        reviewedAt: DateTime.now(),
      );

  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) async => items.first.copyWith(
        status: AppointmentStatus.checkedIn,
        queueNumber: 1,
        checkedInAt: DateTime.now(),
        roomNumber: roomNumber ?? 'Phòng 204 - Tầng 2',
      );
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: child,
    );

void main() {
  testWidgets('PatientHomeScreen displays empty upcoming appointment card', (tester) async {
    final repo = _FakeHomeRepo([]);

    await tester.pumpWidget(_app(PatientHomeScreen(appointmentRepository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Tiện ích nhanh'), findsOneWidget);
    expect(find.text('Lịch khám sắp tới'), findsOneWidget);
    expect(find.text('Chưa có lịch khám sắp tới'), findsOneWidget);
    expect(find.text('Hỗ trợ khẩn cấp'), findsOneWidget);
  });

  testWidgets('PatientHomeScreen displays active upcoming appointment card', (tester) async {
    final appointment = Appointment(
      id: 'APT-100',
      doctorId: 'DOC-01',
      doctorName: 'BS. Trần Thảo Linh',
      department: 'Nội tiết',
      specialty: 'Nội tiết',
      departmentId: 'endocrinology',
      date: DateTime.now().add(const Duration(days: 1)),
      time: '09:00',
      reason: 'Khám kiểm tra định kỳ',
      status: AppointmentStatus.confirmed,
    );

    final repo = _FakeHomeRepo([appointment]);

    await tester.pumpWidget(_app(PatientHomeScreen(appointmentRepository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);
    expect(find.text('Nội tiết'), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsOneWidget);
    expect(find.text('Chi tiết'), findsOneWidget);
  });

  testWidgets('Tapping emergency support shows bottom sheet', (tester) async {
    final repo = _FakeHomeRepo([]);

    await tester.pumpWidget(_app(PatientHomeScreen(appointmentRepository: repo)));
    await tester.pumpAndSettle();

    final btnFinder = find.text('Hỗ trợ khẩn cấp');
    await tester.ensureVisible(btnFinder);
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    expect(find.text('Hỗ trợ Y tế & Cấp cứu khẩn cấp'), findsOneWidget);
    expect(find.text('Gọi cấp cứu 115'), findsOneWidget);
    expect(find.text('Tổng đài Smart Hospital'), findsOneWidget);
  });
}
