import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_dashboard_screen.dart';

class _MockDoctorAppointmentRepository implements AppointmentRepository {
  _MockDoctorAppointmentRepository(this.items);

  List<Appointment> items;
  int updateCalls = 0;
  AppointmentStatus? lastUpdatedStatus;
  String? lastDiagnosis;
  String? lastPrescription;

  @override
  Future<List<Appointment>> getDoctorAppointments({
    String? doctorId,
    DateTime? date,
  }) async =>
      items;

  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status, {
    String? note,
    String? diagnosis,
    String? prescription,
    DateTime? followUpDate,
  }) async {
    updateCalls++;
    lastUpdatedStatus = status;
    lastDiagnosis = diagnosis;
    lastPrescription = prescription;

    final idx = items.indexWhere((a) => a.id == id);
    final updated = items[idx].copyWith(
      status: status,
      statusNote: note,
      diagnosis: diagnosis,
      prescription: prescription,
      followUpDate: followUpDate,
      updatedAt: DateTime(2026, 11, 20),
    );
    items[idx] = updated;
    return updated;
  }

  @override
  Future<List<AppointmentSlot>> getAvailableSlots(
    String doctorId,
    DateTime selectedDate,
  ) async =>
      const [];

  @override
  Future<Appointment> createAppointment(Appointment appointment) async =>
      appointment;

  @override
  Future<List<Appointment>> getAppointments() async => items;

  @override
  Future<List<Appointment>> getMyAppointments() async => items;

  @override
  Future<Appointment?> getAppointmentById(String id) async =>
      items.where((x) => x.id == id).firstOrNull;

  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) async =>
      updateAppointmentStatus(id, AppointmentStatus.cancelled, note: reason);

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async {
    final idx = items.indexWhere((a) => a.id == id);
    final updated = items[idx].copyWith(
      rating: rating,
      reviewNote: reviewNote,
      reviewedAt: DateTime(2026, 11, 20),
    );
    items[idx] = updated;
    return updated;
  }

  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) async {
    final idx = items.indexWhere((a) => a.id == id);
    final updated = items[idx].copyWith(
      status: AppointmentStatus.checkedIn,
      queueNumber: 1,
      checkedInAt: DateTime(2026, 11, 20),
      roomNumber: roomNumber ?? 'Phòng 204 - Tầng 2',
    );
    items[idx] = updated;
    return updated;
  }
}

final _testDate = DateTime(2026, 11, 20);

final _pendingItem = Appointment(
  id: 'APT-DOC-1',
  patientId: 'patient-1',
  patientName: 'Nguyễn Văn A',
  doctorId: 'dr-linh',
  doctorName: 'BS. Trần Thảo Linh',
  specialty: 'Tim mạch',
  department: 'Khoa Tim mạch',
  date: _testDate,
  time: '08:30',
  reason: 'Đau tức ngực',
  status: AppointmentStatus.pending,
);

final _confirmedItem = Appointment(
  id: 'APT-DOC-2',
  patientId: 'patient-2',
  patientName: 'Lê Thị B',
  doctorId: 'dr-linh',
  doctorName: 'BS. Trần Thảo Linh',
  specialty: 'Tim mạch',
  department: 'Khoa Tim mạch',
  date: _testDate,
  time: '09:30',
  reason: 'Tái khám huyết áp',
  status: AppointmentStatus.confirmed,
);

final _completedItem = Appointment(
  id: 'APT-DOC-3',
  patientId: 'patient-3',
  patientName: 'Trần Văn C',
  doctorId: 'dr-linh',
  doctorName: 'BS. Trần Thảo Linh',
  specialty: 'Tim mạch',
  department: 'Khoa Tim mạch',
  date: _testDate,
  time: '10:30',
  reason: 'Khó thở',
  status: AppointmentStatus.completed,
  diagnosis: 'Viêm phế quản co thắt',
  prescription: '1. Ventolin xịt\n2. Cefixim 200mg',
);

Widget _testApp(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('DoctorDashboard displays header and appointment cards', (
    tester,
  ) async {
    final repo = _MockDoctorAppointmentRepository([
      _pendingItem,
      _confirmedItem,
      _completedItem,
    ]);

    await tester.pumpWidget(
      _testApp(
        DoctorDashboardScreen(
          repository: repo,
          doctorId: 'dr-linh',
          doctorName: 'BS. Trần Thảo Linh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Doctor Info
    expect(find.text('Cổng Bác sĩ (Doctor Portal)'), findsOneWidget);
    expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);

    // Verify Stats
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsWidgets);

    // Verify Appointments
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Lê Thị B'), findsOneWidget);
    expect(find.text('Trần Văn C'), findsOneWidget);
  });

  testWidgets('Doctor confirms a pending appointment', (tester) async {
    final repo = _MockDoctorAppointmentRepository([_pendingItem]);

    await tester.pumpWidget(
      _testApp(
        DoctorDashboardScreen(
          repository: repo,
          doctorId: 'dr-linh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận lịch'), findsOneWidget);
    await tester.ensureVisible(find.text('Xác nhận lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận lịch'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastUpdatedStatus, AppointmentStatus.confirmed);
  });

  testWidgets('Doctor rejects a pending appointment', (tester) async {
    final repo = _MockDoctorAppointmentRepository([_pendingItem]);

    await tester.pumpWidget(
      _testApp(
        DoctorDashboardScreen(
          repository: repo,
          doctorId: 'dr-linh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Từ chối'), findsOneWidget);
    await tester.ensureVisible(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastUpdatedStatus, AppointmentStatus.cancelled);
  });

  testWidgets('Doctor conducts examination and completes appointment', (
    tester,
  ) async {
    final repo = _MockDoctorAppointmentRepository([_confirmedItem]);

    await tester.pumpWidget(
      _testApp(
        DoctorDashboardScreen(
          repository: repo,
          doctorId: 'dr-linh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tiến hành khám'), findsOneWidget);
    await tester.ensureVisible(find.text('Tiến hành khám'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiến hành khám'));
    await tester.pumpAndSettle();

    // In DoctorExaminationScreen
    expect(find.text('Khám & Kê đơn thuốc'), findsOneWidget);
    expect(find.text('Chẩn đoán bệnh *'), findsOneWidget);

    // Fill diagnosis & prescription
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Chẩn đoán bệnh *'),
      'Tăng huyết áp vô căn độ 1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Toa thuốc kê cho bệnh nhân'),
      'Amlodipin 5mg - 1 viên/ngày',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lời dặn / Hẹn ngày tái khám'),
      'Ăn nhạt, tập thể dục nhẹ, tái khám sau 1 tháng',
    );

    await tester.ensureVisible(find.text('Hoàn tất ca khám'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn tất ca khám'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastUpdatedStatus, AppointmentStatus.completed);
    expect(repo.lastDiagnosis, 'Tăng huyết áp vô căn độ 1');
    expect(repo.lastPrescription, 'Amlodipin 5mg - 1 viên/ngày');
  });

  testWidgets('Doctor views completed examination record detail', (
    tester,
  ) async {
    final repo = _MockDoctorAppointmentRepository([_completedItem]);

    await tester.pumpWidget(
      _testApp(
        DoctorDashboardScreen(
          repository: repo,
          doctorId: 'dr-linh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xem bệnh án & đơn thuốc'), findsOneWidget);
    await tester.ensureVisible(find.text('Xem bệnh án & đơn thuốc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem bệnh án & đơn thuốc'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết bệnh án & Đơn thuốc'), findsOneWidget);
    expect(find.text('Viêm phế quản co thắt'), findsOneWidget);
    expect(find.text('1. Ventolin xịt\n2. Cefixim 200mg'), findsOneWidget);
  });
}
