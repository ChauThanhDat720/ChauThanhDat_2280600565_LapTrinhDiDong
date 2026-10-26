import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/appointments/domain/hospital_navigation.dart';
import 'package:smart_hospital/features/appointments/presentation/digital_boarding_pass_screen.dart';

class _MockNavigationAppointmentRepository implements AppointmentRepository {
  _MockNavigationAppointmentRepository(this.item);

  Appointment item;

  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) async {
    final updated = item.copyWith(
      status: AppointmentStatus.checkedIn,
      queueNumber: 3,
      checkedInAt: DateTime.now(),
      roomNumber: roomNumber ?? item.roomNumber ?? 'Phòng 204 - Tầng 2',
    );
    item = updated;
    return updated;
  }

  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) async => item;

  @override
  Future<Appointment> createAppointment(Appointment appointment) async => item;

  @override
  Future<Appointment?> getAppointmentById(String id) async => item;

  @override
  Future<List<Appointment>> getAppointments() async => [item];

  @override
  Future<List<AppointmentSlot>> getAvailableSlots(
    String doctorId,
    DateTime selectedDate,
  ) async =>
      const [];

  @override
  Future<List<Appointment>> getDoctorAppointments({
    String? doctorId,
    DateTime? date,
  }) async =>
      [item];

  @override
  Future<List<Appointment>> getMyAppointments() async => [item];

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async =>
      item;

  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status, {
    String? note,
    String? diagnosis,
    String? prescription,
    DateTime? followUpDate,
  }) async =>
      item;
}

void main() {
  group('Hospital Navigation Domain Resolver Tests (Flexible per Doctor)', () {
    test('Resolves route for Cardiology (BS. Trần Thảo Linh - Khu B Tầng 2)', () {
      final apt = Appointment(
        id: 'APT-NAV-1',
        patientId: 'PAT-1',
        patientName: 'Nguyễn Văn A',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Tim mạch',
        specialty: 'Bác sĩ tim mạch',
        date: DateTime(2026, 11, 20),
        time: '08:30',
        reason: 'Khám tim định kỳ',
        status: AppointmentStatus.confirmed,
      );

      final route = HospitalNavigationResolver.resolveRoute(apt);

      expect(route.buildingWing, 'Khu B');
      expect(route.floor, 'Tầng 2');
      expect(route.clinicRoom, contains('Phòng 204'));
      expect(route.elevatorNote, contains('Trụ B'));
      expect(route.paraclinicalLab, contains('Phòng 208'));
      expect(route.pharmacyDesk, contains('Quầy Dược số 2'));
      expect(route.steps.length, 4);
      expect(route.steps[0].isDone, false); // Not checked-in yet
      expect(route.steps[0].isCurrent, true);
    });

    test('Resolves route for Pediatrics (BS. Nguyễn Đức Minh - Khu A Tầng 1)', () {
      final apt = Appointment(
        id: 'APT-NAV-2',
        patientId: 'PAT-2',
        patientName: 'Bé Nguyễn An',
        doctorId: 'dr-duc',
        doctorName: 'BS. Nguyễn Đức Minh',
        department: 'Nhi khoa',
        specialty: 'Bác sĩ nhi khoa',
        date: DateTime(2026, 11, 20),
        time: '09:00',
        reason: 'Sốt phát ban',
        status: AppointmentStatus.checkedIn,
        queueNumber: 5,
        roomNumber: 'Phòng 105 - Tầng 1',
      );

      final route = HospitalNavigationResolver.resolveRoute(apt);

      expect(route.buildingWing, 'Khu A');
      expect(route.floor, 'Tầng 1');
      expect(route.clinicRoom, contains('Phòng 105'));
      expect(route.paraclinicalLab, contains('Phòng 108'));
      expect(route.pharmacyDesk, contains('Quầy Dược số 1'));
      expect(route.steps[0].isDone, true); // Checked-in
      expect(route.steps[1].isCurrent, true); // Waiting in front of room 105
    });

    test('Resolves route for Dermatology (BS. Phạm Ngọc Lan - Khu C Tầng 3)', () {
      final apt = Appointment(
        id: 'APT-NAV-3',
        patientId: 'PAT-3',
        patientName: 'Lê Hoàng Yến',
        doctorId: 'dr-lan',
        doctorName: 'BS. Phạm Ngọc Lan',
        department: 'Da liễu',
        specialty: 'Bác sĩ da liễu',
        date: DateTime(2026, 11, 20),
        time: '14:30',
        reason: 'Viêm da dị ứng',
        status: AppointmentStatus.completed,
      );

      final route = HospitalNavigationResolver.resolveRoute(apt);

      expect(route.buildingWing, 'Khu C');
      expect(route.floor, 'Tầng 3');
      expect(route.clinicRoom, contains('Phòng 302'));
      expect(route.paraclinicalLab, contains('Phòng 305'));
      expect(route.steps[0].isDone, true);
      expect(route.steps[1].isDone, true);
      expect(route.steps[3].badge, contains('SẴN SÀNG NHẬN THUỐC'));
    });

    test('Falls back dynamically for custom/new doctor not in dictionary', () {
      final customApt = Appointment(
        id: 'APT-CUSTOM',
        patientId: 'PAT-99',
        patientName: 'Trần Văn Mới',
        doctorId: 'dr-custom-ortho',
        doctorName: 'BS. Vũ Minh Hoàng',
        department: 'Chấn thương chỉnh hình',
        specialty: 'Cơ xương khớp',
        date: DateTime(2026, 11, 20),
        time: '15:00',
        reason: 'Đau khớp gối',
        status: AppointmentStatus.confirmed,
      );

      final route = HospitalNavigationResolver.resolveRoute(customApt);

      // Falls back to orthopedics wing/floor (Khu A Tầng 1)
      expect(route.buildingWing, 'Khu A');
      expect(route.floor, 'Tầng 1');
      expect(route.steps.length, 4);
    });
  });

  group('DigitalBoardingPassScreen Indoor Navigation UI Tests', () {
    testWidgets('Renders dynamic 4-step route and opens floor map bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final apt = Appointment(
        id: 'APT-BOARDING-NAV',
        patientId: 'PAT-TEST',
        patientName: 'Hoàng Văn Thắng',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Tim mạch',
        specialty: 'Bác sĩ tim mạch',
        date: DateTime.now(),
        time: '10:00',
        reason: 'Tức ngực khó thở',
        status: AppointmentStatus.confirmed,
      );

      final repo = _MockNavigationAppointmentRepository(apt);

      await tester.pumpWidget(
        MaterialApp(
          home: DigitalBoardingPassScreen(
            appointment: apt,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Navigation Card Header
      expect(find.text('LỘ TRÌNH CHỈ ĐƯỜNG THÔNG MINH'), findsOneWidget);
      expect(
        find.textContaining('BS. Trần Thảo Linh'),
        findsWidgets,
      );

      // Verify Step 1: Reception
      expect(find.text('BƯỚC 1:'), findsOneWidget);
      expect(find.text('Tiếp đón & Xác thực Check-in'), findsOneWidget);

      // Verify Step 2: Doctor Clinic
      expect(find.text('BƯỚC 2:'), findsOneWidget);
      expect(find.textContaining('Khám chuyên khoa với BS. Trần Thảo Linh'), findsOneWidget);
      expect(find.textContaining('Phòng 204'), findsWidgets);

      // Verify Step 3: Paraclinical Lab
      expect(find.text('BƯỚC 3:'), findsOneWidget);
      expect(find.text('Thực hiện Cận lâm sàng (Nếu có chỉ định)'), findsOneWidget);
      expect(find.textContaining('Phòng 208'), findsWidgets);

      // Verify Step 4: Pharmacy
      expect(find.text('BƯỚC 4:'), findsOneWidget);
      expect(find.text('Thanh toán & Nhận thuốc theo đơn'), findsOneWidget);
      expect(find.textContaining('Quầy Dược số 2'), findsWidgets);

      // Verify Sơ đồ Mặt bằng Bệnh viện button
      final mapButton = find.text('Xem Sơ đồ Toà nhà & Mặt bằng Bệnh viện');
      expect(mapButton, findsOneWidget);

      // Scroll to button & tap
      await tester.ensureVisible(mapButton);
      await tester.pumpAndSettle();
      await tester.tap(mapButton);
      await tester.pumpAndSettle();

      // Verify Floor Map Modal opens
      expect(find.text('SƠ ĐỒ MẶT BẰNG BỆNH VIỆN'), findsOneWidget);
      expect(find.text('Tầng 2'), findsWidgets);
      expect(find.text('ĐÍCH ĐẾN CỦA BẠN'), findsOneWidget);
    });
  });
}
