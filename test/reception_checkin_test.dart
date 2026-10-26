import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/theme/app_theme.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/appointments/presentation/digital_boarding_pass_screen.dart';
import 'package:smart_hospital/features/appointments/presentation/reception_checkin_screen.dart';

class _FakeCheckinRepo implements AppointmentRepository {
  _FakeCheckinRepo(this.items);
  List<Appointment> items;

  @override
  Future<List<Appointment>> getMyAppointments() async => items;

  @override
  Future<List<Appointment>> getAppointments() async => items;

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
  }) async {
    final idx = items.indexWhere((a) => a.id == id);
    final updated = items[idx].copyWith(status: status);
    items[idx] = updated;
    return updated;
  }

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async => items.first;

  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) async {
    final idx = items.indexWhere((a) => a.id == id);
    if (idx < 0) throw Exception('Không tìm thấy lịch hẹn $id');
    final updated = items[idx].copyWith(
      status: AppointmentStatus.checkedIn,
      queueNumber: 7,
      checkedInAt: DateTime(2026, 11, 20, 8, 30),
      roomNumber: roomNumber ?? 'Phòng 204 - Tầng 2',
    );
    items[idx] = updated;
    return updated;
  }
}

Widget _buildTestApp(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: child,
    );

void main() {
  final sampleAppointment = Appointment(
    id: 'APT-101',
    doctorId: 'DOC-01',
    doctorName: 'BS. Trần Thảo Linh',
    specialty: 'Tim mạch',
    department: 'Khoa Tim mạch',
    departmentId: 'cardio',
    patientName: 'Nguyễn Văn An',
    date: DateTime(2026, 11, 20),
    time: '09:00',
    reason: 'Tái khám định kỳ',
    status: AppointmentStatus.confirmed,
  );

  group('Digital Boarding Pass & Reception Check-in Tests', () {
    testWidgets('DigitalBoardingPassScreen displays boarding pass with QR and doctor info', (tester) async {
      final repo = _FakeCheckinRepo([sampleAppointment]);

      await tester.pumpWidget(
        _buildTestApp(
          DigitalBoardingPassScreen(
            appointment: sampleAppointment,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Patient info
      expect(find.text('Thẻ Tiếp đón Phòng khám'), findsOneWidget);
      expect(find.text('THẺ TIẾP ĐÓN PHÒNG KHÁM'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);

      // Verify Checkin button exists for confirmed status
      expect(find.text('Mô phỏng Quét Check-in Ngay'), findsOneWidget);
      await tester.ensureVisible(find.text('Mô phỏng Quét Check-in Ngay'));
      await tester.pumpAndSettle();

      // Tap simulate checkin
      await tester.tap(find.text('Mô phỏng Quét Check-in Ngay'));
      await tester.pumpAndSettle();

      // Verify status changed to checkedIn and STT is displayed
      expect(find.text('STT: 07'), findsOneWidget);
      expect(find.text('PHIẾU ĐÃ TIẾP ĐÓN - CHỜ KHÁM'), findsOneWidget);
    });

    testWidgets('ReceptionCheckinScreen performs checkin and displays queue in waiting room', (tester) async {
      final repo = _FakeCheckinRepo([sampleAppointment]);

      await tester.pumpWidget(
        _buildTestApp(
          ReceptionCheckinScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify tabs & title
      expect(find.text('Quầy Tiếp đón & Kiosk Check-in'), findsOneWidget);
      expect(find.text('Ca khám sẵn sàng tiếp đón hôm nay'), findsOneWidget);

      // Tap 'Tiếp đón' on list item
      await tester.tap(find.widgetWithText(FilledButton, 'Tiếp đón').last);
      await tester.pumpAndSettle();

      // Verify Success Dialog popup
      expect(find.text('Tiếp đón thành công!'), findsOneWidget);
      expect(find.text('SỐ THỨ TỰ KHÁM (STT)'), findsOneWidget);
      expect(find.text('07'), findsOneWidget);

      // Close Dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      // Switch to Waiting Room Queue Tab
      await tester.tap(find.byIcon(Icons.queue_play_next_rounded));
      await tester.pumpAndSettle();

      // Verify waiting queue displays the checked in patient with STT 07 and 'Đang gọi'
      expect(find.text('07'), findsOneWidget);
      expect(find.text('Đang gọi'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
    });
  });
}
