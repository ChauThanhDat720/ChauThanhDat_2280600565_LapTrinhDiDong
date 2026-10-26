import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/appointments/presentation/appointment_list_screen.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_dashboard_screen.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_screens.dart';
import 'package:smart_hospital/features/home/presentation/home_screen.dart';

void main() {
  group('Follow-up Appointment Domain Tests', () {
    test('Appointment domain correctly handles follow-up properties', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 14));

      final completedApt = Appointment(
        id: 'apt-prev-001',
        patientId: 'patient-1',
        patientName: 'Nguyễn Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Bác sĩ tim mạch',
        department: 'Tim mạch',
        date: now.subtract(const Duration(days: 1)),
        time: '08:30',
        reason: 'Đau thắt ngực',
        status: AppointmentStatus.completed,
        followUpDate: targetDate,
        statusNote: 'Uống thuốc 14 ngày và tái khám kiểm tra lại huyết áp',
      );

      expect(completedApt.hasActiveFollowUp, true);
      expect(completedApt.followUpDaysRemaining, 14);
      expect(completedApt.isFollowUp, false);
      expect(completedApt.parentAppointmentId, isNull);

      final rebookedApt = Appointment(
        id: 'apt-followup-002',
        patientId: 'patient-1',
        patientName: 'Nguyễn Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Bác sĩ tim mạch',
        department: 'Tim mạch',
        date: targetDate,
        time: '09:00',
        reason: 'Tái khám theo chỉ định của BS. Trần Thảo Linh',
        status: AppointmentStatus.confirmed,
        isFollowUp: true,
        parentAppointmentId: completedApt.id,
      );

      expect(rebookedApt.isFollowUp, true);
      expect(rebookedApt.parentAppointmentId, 'apt-prev-001');

      final json = rebookedApt.toJson();
      expect(json['is_follow_up'], true);
      expect(json['parent_appointment_id'], 'apt-prev-001');

      final deserialized = Appointment.fromJson(json);
      expect(deserialized.isFollowUp, true);
      expect(deserialized.parentAppointmentId, 'apt-prev-001');
    });
  });

  group('Follow-up Care & 1-Click Re-booking UI Tests', () {
    testWidgets('PatientHomeScreen displays Follow-up Reminder Card and opens 1-Click Re-booking', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final targetFollowUp = now.add(const Duration(days: 7));

      final completedApt = Appointment(
        id: 'apt-seed-completed',
        patientId: 'demo-patient',
        patientName: 'Nguyễn Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Bác sĩ tim mạch',
        department: 'Tim mạch',
        date: now.subtract(const Duration(days: 7)),
        time: '08:30',
        reason: 'Tăng huyết áp',
        status: AppointmentStatus.completed,
        followUpDate: targetFollowUp,
        statusNote: 'Uống thuốc 7 ngày và tái khám kiểm tra lại huyết áp',
      );

      AppointmentStore.instance.clearForTest();
      AppointmentStore.instance.addAppointment(completedApt);

      await tester.pumpWidget(
        const MaterialApp(
          home: PatientHomeScreen(
            appointmentRepository: LocalAppointmentRepository(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Follow-up Reminder card exists on Patient Home Screen
      expect(find.text('LỊCH HẸN TÁI KHÁM ĐỊNH KỲ'), findsOneWidget);
      expect(find.textContaining('BS. Trần Thảo Linh'), findsWidgets);
      expect(find.textContaining('Còn 7 ngày nữa'), findsOneWidget);
      expect(find.text('1 chạm Đặt lịch tái khám'), findsOneWidget);
      expect(find.text('Xem bệnh án cũ'), findsOneWidget);

      // Tap 1-Click Re-booking button
      await tester.tap(find.text('1 chạm Đặt lịch tái khám'));
      await tester.pumpAndSettle();

      // Verify BookAppointmentScreen opens with pre-filled doctor, follow-up banner and date
      expect(find.text('LỊCH TÁI KHÁM THEO CHỈ ĐỊNH'), findsOneWidget);
      expect(find.textContaining('Bác sĩ BS. Trần Thảo Linh đã chỉ định bạn tái khám'), findsOneWidget);
      expect(find.byType(BookAppointmentScreen), findsOneWidget);
    });

    testWidgets('DoctorDashboardScreen displays TÁI KHÁM badge on follow-up appointments', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final followUpApt = Appointment(
        id: 'apt-followup-live',
        patientId: 'patient-1',
        patientName: 'Trần Văn Bình',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Bác sĩ tim mạch',
        department: 'Khoa Tim mạch',
        date: now,
        time: '09:00',
        reason: 'Tái khám theo dõi huyết áp',
        status: AppointmentStatus.confirmed,
        isFollowUp: true,
        parentAppointmentId: 'apt-old-01',
      );

      AppointmentStore.instance.clearForTest();
      AppointmentStore.instance.addAppointment(followUpApt);

      await tester.pumpWidget(
        const MaterialApp(
          home: DoctorDashboardScreen(
            doctorId: 'dr-linh',
            doctorName: 'BS. Trần Thảo Linh',
            department: 'Khoa Tim mạch',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify TÁI KHÁM badge is visible on the doctor card
      expect(find.text('TÁI KHÁM'), findsOneWidget);
      expect(find.text('Trần Văn Bình'), findsOneWidget);
    });

    testWidgets('AppointmentDetailScreen renders 1-click rebooking button for completed appointment with followUpDate', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final followUpDate = now.add(const Duration(days: 14));

      final completedApt = Appointment(
        id: 'apt-detail-followup',
        patientId: 'patient-1',
        patientName: 'Lê Hoàng Nam',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Bác sĩ tim mạch',
        department: 'Tim mạch',
        date: now.subtract(const Duration(days: 3)),
        time: '10:00',
        reason: 'Khám định kỳ',
        status: AppointmentStatus.completed,
        followUpDate: followUpDate,
        statusNote: 'Tái khám sau 14 ngày',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: completedApt,
            repository: const LocalAppointmentRepository(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify 1-click re-booking button is shown
      expect(find.textContaining('1 chạm Đặt lịch tái khám'), findsOneWidget);
    });
  });
}
