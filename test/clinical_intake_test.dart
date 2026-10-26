import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/appointments/presentation/appointment_list_screen.dart';
import 'package:smart_hospital/features/clinical_intake/data/clinical_intake_repository.dart';
import 'package:smart_hospital/features/clinical_intake/domain/clinical_intake.dart';
import 'package:smart_hospital/features/clinical_intake/presentation/pre_visit_intake_screen.dart';
import 'package:smart_hospital/features/clinical_intake/presentation/widgets/intake_summary_card.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_dashboard_screen.dart';

void main() {
  group('Clinical Intake Domain Tests', () {
    test('ClinicalIntake domain correctly computes severity, emoji, and JSON serialization', () {
      final now = DateTime(2026, 10, 26, 10, 0);

      final mildIntake = ClinicalIntake(
        id: 'intake-1',
        appointmentId: 'APT-1',
        patientId: 'P-1',
        chiefComplaint: 'Hơi nhức đầu nhẹ',
        painLevel: 2,
        painLocation: 'Đầu / Não',
        onsetDuration: 'Hôm nay',
        symptoms: ['Chóng mặt'],
        submittedAt: now,
      );

      expect(mildIntake.painSeverityLabel, 'Nhẹ (1-3)');
      expect(mildIntake.painEmoji, '😊');
      expect(mildIntake.painColor, const Color(0xFF16A34A));

      final moderateIntake = mildIntake.copyWith(painLevel: 5);
      expect(moderateIntake.painSeverityLabel, 'Vừa phải (4-6)');
      expect(moderateIntake.painEmoji, '🙁');

      final severeIntake = mildIntake.copyWith(painLevel: 8);
      expect(severeIntake.painSeverityLabel, 'Dữ dội (7-8)');
      expect(severeIntake.painEmoji, '😣');

      final verySevereIntake = mildIntake.copyWith(
        painLevel: 10,
        knownAllergies: 'Dị ứng Penicillin',
        currentMedications: 'Panadol',
      );
      expect(verySevereIntake.painSeverityLabel, 'Rất dữ dội (9-10)');
      expect(verySevereIntake.painEmoji, '😭');
      expect(verySevereIntake.painColor, const Color(0xFFDC2626));

      // Test JSON roundtrip
      final json = verySevereIntake.toJson();
      expect(json['appointment_id'], 'APT-1');
      expect(json['pain_level'], 10);
      expect(json['known_allergies'], 'Dị ứng Penicillin');

      final restored = ClinicalIntake.fromJson(json);
      expect(restored.id, 'intake-1');
      expect(restored.appointmentId, 'APT-1');
      expect(restored.painLevel, 10);
      expect(restored.knownAllergies, 'Dị ứng Penicillin');
      expect(restored.symptoms, ['Chóng mặt']);
    });
  });

  group('Clinical Intake Repository & Store Tests', () {
    setUp(() {
      ClinicalIntakeStore.instance.clearForTest();
      AppointmentStore.instance.clearForTest();
    });

    test('ClinicalIntakeStore seeds sample data and retrieves correctly', () {
      ClinicalIntakeStore.instance.seedIfEmpty();

      final intake101 = ClinicalIntakeStore.instance.getByAppointmentId('APT-101');
      expect(intake101, isNotNull);
      expect(intake101!.chiefComplaint, contains('Đau tức ngực trái'));
      expect(intake101.painLevel, 6);
      expect(intake101.knownAllergies, contains('Penicillin'));

      final intake103 = ClinicalIntakeStore.instance.getByAppointmentId('APT-103');
      expect(intake103, isNotNull);
      expect(intake103!.painLocation, contains('Hô hấp'));
    });

    test('LocalClinicalIntakeRepository saves intake and marks appointment hasIntake', () async {
      final appt = Appointment(
        id: 'APT-TEST-99',
        patientId: 'P-99',
        patientName: 'Lê Văn Test',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Tim mạch',
        department: 'Khoa Tim mạch',
        date: DateTime(2026, 10, 27),
        time: '09:00',
        reason: 'Khám kiểm tra',
        status: AppointmentStatus.confirmed,
        hasIntake: false,
      );
      AppointmentStore.instance.addAppointment(appt);

      const repo = LocalClinicalIntakeRepository();
      final newIntake = ClinicalIntake(
        id: 'intake-APT-TEST-99',
        appointmentId: 'APT-TEST-99',
        patientId: 'P-99',
        chiefComplaint: 'Đau thắt ngực khi leo cầu thang',
        painLevel: 7,
        painLocation: 'Ngực / Tim mạch',
        onsetDuration: '3 ngày trước',
        symptoms: ['Đau thắt ngực', 'Khó thở khi gắng sức'],
        knownAllergies: 'Dị ứng kháng sinh Cefalosporin',
        submittedAt: DateTime.now(),
      );

      final saved = await repo.saveIntake(newIntake);
      expect(saved.appointmentId, 'APT-TEST-99');

      final retrieved = await repo.getIntake('APT-TEST-99');
      expect(retrieved, isNotNull);
      expect(retrieved!.painLevel, 7);

      // Verify Appointment in store is marked hasIntake = true
      final updatedAppt = AppointmentStore.instance.appointments
          .firstWhere((a) => a.id == 'APT-TEST-99');
      expect(updatedAppt.hasIntake, true);
    });
  });

  group('Clinical Intake UI Widget Tests', () {
    setUp(() {
      ClinicalIntakeStore.instance.clearForTest();
      AppointmentStore.instance.clearForTest();
    });

    testWidgets('IntakeSummaryCard renders pain VAS badge and allergy warning', (tester) async {
      final intake = ClinicalIntake(
        id: 'intake-widget-test',
        appointmentId: 'APT-W-1',
        patientId: 'P-1',
        chiefComplaint: 'Đau buốt ngực sau xương ức',
        painLocation: 'Ngực / Tim mạch',
        onsetDuration: '2 ngày trước',
        painLevel: 8,
        symptoms: ['Đau thắt ngực', 'Vã mồ hôi lạnh'],
        knownAllergies: 'Dị ứng nhóm Penicillin nặng',
        currentMedications: 'Aspirin 81mg',
        medicalHistory: 'Tăng huyết áp 3 năm',
        notes: 'Mong bác sĩ kiểm tra thêm động mạch vành',
        submittedAt: DateTime(2026, 10, 26, 8, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IntakeSummaryCard(
                intake: intake,
                isDoctorView: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('BÁO CÁO TRIỆU CHỨNG TIỀN KHÁM (INTAKE SUMMARY)'), findsOneWidget);
      expect(find.text('Đau buốt ngực sau xương ức'), findsOneWidget);
      expect(find.textContaining('VAS: 8/10'), findsOneWidget);
      expect(find.text('Đau thắt ngực'), findsOneWidget);
      expect(find.text('Vã mồ hôi lạnh'), findsOneWidget);
      expect(find.textContaining('Dị ứng nhóm Penicillin nặng'), findsOneWidget);
      expect(find.textContaining('Aspirin 81mg'), findsOneWidget);
      expect(find.textContaining('Tăng huyết áp 3 năm'), findsOneWidget);
      expect(find.textContaining('Mong bác sĩ kiểm tra thêm động mạch vành'), findsOneWidget);
    });

    testWidgets('PreVisitIntakeScreen allows filling and submitting survey', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appt = Appointment(
        id: 'APT-INTAKE-FORM',
        patientId: 'P-1',
        patientName: 'Trần Văn Khang',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Tim mạch',
        department: 'Khoa Tim mạch',
        date: DateTime(2026, 10, 27),
        time: '10:00',
        reason: 'Hồi hộp đánh trống ngực',
        status: AppointmentStatus.confirmed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PreVisitIntakeScreen(
            appointment: appt,
            repository: const LocalClinicalIntakeRepository(),
          ),
        ),
      );

      expect(find.text('Khai Báo Triệu Chứng Tiền Khám'), findsOneWidget);
      expect(find.textContaining('BS. Trần Thảo Linh'), findsOneWidget);
      expect(find.text('1. Triệu chứng khó chịu chính (Lý do khám)'), findsOneWidget);
      expect(find.text('4. Thang điểm đau trực quan (VAS 1 - 10)'), findsOneWidget);

      // Verify submit button exists
      final submitButton = find.text('Xác Nhận & Gửi Cho Bác Sĩ');
      expect(submitButton, findsOneWidget);

      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Check that it was saved into store
      final savedIntake = ClinicalIntakeStore.instance.getByAppointmentId(appt.id);
      expect(savedIntake, isNotNull);
      expect(savedIntake!.chiefComplaint, 'Hồi hộp đánh trống ngực');
    });

    testWidgets('AppointmentDetailScreen renders intake prompt or card', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appt = Appointment(
        id: 'APT-DETAIL-TEST',
        patientId: 'P-1',
        patientName: 'Trần Văn Khang',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Tim mạch',
        department: 'Khoa Tim mạch',
        date: DateTime(2026, 10, 27),
        time: '10:00',
        reason: 'Khám định kỳ',
        status: AppointmentStatus.confirmed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appt,
            repository: const LocalAppointmentRepository(),
          ),
        ),
      );

      expect(find.text('Khai báo triệu chứng trước khám'), findsOneWidget);
      expect(find.text('Điền phiếu triệu chứng tiền khám'), findsOneWidget);
    });

    testWidgets('DoctorExaminationScreen shows pre-visit intake summary to doctor', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      ClinicalIntakeStore.instance.seedIfEmpty();

      final appt101 = Appointment(
        id: 'APT-101',
        patientId: 'BN-01',
        patientName: 'Nguyễn Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Tim mạch',
        department: 'Khoa Tim mạch',
        date: DateTime(2026, 10, 26),
        time: '08:30',
        reason: 'Đau thắt ngực',
        status: AppointmentStatus.confirmed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorExaminationScreen(
            appointment: appt101,
            repository: const LocalAppointmentRepository(),
          ),
        ),
      );

      expect(find.text('BÁO CÁO TRIỆU CHỨNG TIỀN KHÁM (INTAKE SUMMARY)'), findsOneWidget);
      expect(find.textContaining('Đau tức ngực trái âm ỉ'), findsOneWidget);
    });
  });
}
