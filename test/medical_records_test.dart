import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/theme/app_theme.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/medical_records/presentation/medical_records_screen.dart';

class _MockRecordRepo implements AppointmentRepository {
  _MockRecordRepo(this.items);
  List<Appointment> items;

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
  }) async => items.first;

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async {
    final updated = items.first.copyWith(
      rating: rating,
      reviewNote: reviewNote,
      reviewedAt: DateTime.now(),
    );
    items = [updated];
    return updated;
  }

  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) async {
    final updated = items.first.copyWith(
      status: AppointmentStatus.checkedIn,
      queueNumber: 1,
      checkedInAt: DateTime.now(),
      roomNumber: roomNumber ?? 'Phòng 204 - Tầng 2',
    );
    items = [updated];
    return updated;
  }
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: child,
    );

void main() {
  testWidgets('MedicalRecordsScreen displays empty state when no completed appointments', (tester) async {
    final repo = _MockRecordRepo([]);

    await tester.pumpWidget(_app(MedicalRecordsScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Sổ khám & Đơn thuốc'), findsOneWidget);
    expect(find.text('Chưa có hồ sơ bệnh án nào'), findsOneWidget);
  });

  testWidgets('MedicalRecordsScreen displays completed examination records and filters with search', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final item1 = Appointment(
      id: 'REC-01',
      doctorId: 'DOC-01',
      doctorName: 'BS. Trần Thảo Linh',
      specialty: 'Tim mạch',
      department: 'Khoa Tim mạch',
      departmentId: 'cardio',
      date: DateTime(2026, 11, 10),
      time: '08:30',
      reason: 'Đau tức ngực',
      status: AppointmentStatus.completed,
      diagnosis: 'Thiếu máu cơ tim cục bộ',
      prescription: 'Aspirin 81mg - 1 viên/ngày sau ăn',
      statusNote: 'Tránh vận động quá sức',
      rating: 5,
      reviewNote: 'Bác sĩ giải thích rất kỹ',
    );

    final item2 = Appointment(
      id: 'REC-02',
      doctorId: 'DOC-02',
      doctorName: 'BS. Nguyễn Văn Hùng',
      specialty: 'Hô hấp',
      department: 'Khoa Hô hấp',
      departmentId: 'respiratory',
      date: DateTime(2026, 11, 5),
      time: '14:00',
      reason: 'Ho khan có đờm',
      status: AppointmentStatus.completed,
      diagnosis: 'Viêm phế quản co thắt',
      prescription: 'Salbutamol xịt khi khó thở',
    );

    final repo = _MockRecordRepo([item1, item2]);

    await tester.pumpWidget(_app(MedicalRecordsScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);
    expect(find.text('BS. Nguyễn Văn Hùng'), findsOneWidget);
    expect(find.text('Thiếu máu cơ tim cục bộ'), findsOneWidget);
    expect(find.text('Viêm phế quản co thắt'), findsOneWidget);
    expect(find.text('Aspirin 81mg - 1 viên/ngày sau ăn'), findsOneWidget);
    expect(find.text('Xuất phiếu & Đơn (PDF)'), findsNWidgets(2));
    expect(find.text('Nhắc uống thuốc'), findsNWidgets(2));

    // Test search filter
    await tester.enterText(find.byType(TextField), 'Tim mạch');
    await tester.pumpAndSettle();

    expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);
    expect(find.text('BS. Nguyễn Văn Hùng'), findsNothing);
  });
}
