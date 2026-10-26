import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/vaccination/data/vaccination_repository.dart';
import 'package:smart_hospital/features/vaccination/domain/vaccination_record.dart';
import 'package:smart_hospital/features/vaccination/presentation/add_vaccination_screen.dart';
import 'package:smart_hospital/features/vaccination/presentation/vaccination_passport_screen.dart';
import 'package:smart_hospital/features/vaccination/presentation/widgets/vaccine_passport_card.dart';

void main() {
  group('Vaccination Domain Tests', () {
    test('VaccinationRecord computes completion, due dates, and QR verification payload', () {
      final now = DateTime.now();

      final inProgressRecord = VaccinationRecord(
        id: 'vac-test-1',
        patientId: 'BN-01',
        patientName: 'Nguyễn Văn An',
        vaccineName: 'Gardasil 9 (Mỹ)',
        targetDisease: 'HPV',
        doseNumber: 1,
        totalDoses: 3,
        batchNumber: 'BATCH-001',
        manufacturer: 'MSD',
        administeredDate: now.subtract(const Duration(days: 60)),
        nextDoseDate: now.add(const Duration(days: 5)),
        certificateCode: 'VAC-2026-VN-11111',
      );

      expect(inProgressRecord.isCompleted, false);
      expect(inProgressRecord.doseProgressLabel, 'Mũi 1 / 3');
      expect(inProgressRecord.doseProgressFraction, closeTo(0.33, 0.01));
      expect(inProgressRecord.isDueSoon, true);
      expect(inProgressRecord.isOverdue, false);
      expect(inProgressRecord.daysUntilNextDose, 5);
      expect(inProgressRecord.verificationQrData, contains('VAC-2026-VN-11111'));
      expect(inProgressRecord.verificationQrData, contains('IN_PROGRESS'));

      // Completed record
      final completedRecord = inProgressRecord.copyWith(
        doseNumber: 3,
        nextDoseDate: null,
      );
      expect(completedRecord.isCompleted, true);
      expect(completedRecord.doseProgressFraction, 1.0);
      expect(completedRecord.verificationQrData, contains('FULL_IMMUNIZATION'));

      // JSON roundtrip test
      final json = inProgressRecord.toJson();
      expect(json['certificate_code'], 'VAC-2026-VN-11111');
      expect(json['dose_number'], 1);

      final deserialized = VaccinationRecord.fromJson(json);
      expect(deserialized.id, 'vac-test-1');
      expect(deserialized.vaccineName, 'Gardasil 9 (Mỹ)');
      expect(deserialized.nextDoseDate, isNotNull);
    });
  });

  group('Vaccination Repository & Store Tests', () {
    setUp(() {
      VaccinationStore.instance.clearForTest();
    });

    test('VaccinationStore seeds default records and filters by family member', () {
      VaccinationStore.instance.seedIfEmpty();
      expect(VaccinationStore.instance.records.length, 4);

      final selfRecords = VaccinationStore.instance.getByFamilyMember('fam-self');
      expect(selfRecords.length, 3);
      expect(selfRecords.every((r) => r.familyMemberId == 'fam-self'), true);

      final childRecords = VaccinationStore.instance.getByFamilyMember('fam-child');
      expect(childRecords.length, 1);
      expect(childRecords.first.patientName, 'Nguyễn Minh Khang');

      final upcoming = VaccinationStore.instance.getUpcoming();
      expect(upcoming.isNotEmpty, true);
      expect(upcoming.first.vaccineName, contains('Gardasil'));
    });

    test('LocalVaccinationRepository saves new record', () async {
      const repo = LocalVaccinationRepository();
      final newRecord = VaccinationRecord(
        id: 'vac-custom-new',
        patientId: 'BN-01',
        patientName: 'Nguyễn Văn An',
        vaccineName: 'Prevenar 13',
        targetDisease: 'Phế cầu',
        doseNumber: 1,
        totalDoses: 1,
        batchNumber: 'PFIZER-101',
        manufacturer: 'Pfizer',
        administeredDate: DateTime(2026, 10, 26),
        certificateCode: 'VAC-2026-VN-77777',
      );

      final saved = await repo.saveVaccination(newRecord);
      expect(saved.id, 'vac-custom-new');

      final retrieved = await repo.getVaccinationByCertificateCode('VAC-2026-VN-77777');
      expect(retrieved, isNotNull);
      expect(retrieved!.vaccineName, 'Prevenar 13');
    });

    test('LocalVaccinationRepository returns protocols', () async {
      const repo = LocalVaccinationRepository();
      final protocols = await repo.getProtocols();
      expect(protocols.length, 4);
      expect(protocols.first.ageGroup, contains('0 - 12 tuổi'));
    });
  });

  group('Vaccination UI Widget Tests', () {
    setUp(() {
      VaccinationStore.instance.clearForTest();
    });

    testWidgets('VaccinePassportCard renders certificate code and verified status', (tester) async {
      final rec = VaccinationRecord(
        id: 'vac-card-test',
        patientId: 'BN-01',
        patientName: 'Nguyễn Văn An',
        vaccineName: 'Engerix B 20mcg (Bỉ)',
        targetDisease: 'Viêm gan virus B',
        doseNumber: 3,
        totalDoses: 3,
        batchNumber: 'GSK-BE8921',
        manufacturer: 'GSK (Bỉ)',
        administeredDate: DateTime(2026, 4, 15),
        facilityName: 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
        certificateCode: 'VAC-2026-VN-66512',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VaccinePassportCard(record: rec),
            ),
          ),
        ),
      );

      expect(find.text('CHỨNG NHẬN TIÊM CHỦNG ĐIỆN TỬ'), findsOneWidget);
      expect(find.text('DIGITAL CERTIFICATE OF VACCINATION'), findsOneWidget);
      expect(find.text('HOÀN TẤT / VERIFIED'), findsOneWidget);
      expect(find.text('NGUYỄN VĂN AN'), findsOneWidget);
      expect(find.text('VAC-2026-VN-66512'), findsOneWidget);
      expect(find.text('Engerix B 20mcg (Bỉ)'), findsOneWidget);
      expect(find.text('Quét xác thực'), findsOneWidget);
    });

    testWidgets('VaccinationPassportScreen renders tabs, countdown banner and records', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      VaccinationStore.instance.seedIfEmpty();

      await tester.pumpWidget(
        const MaterialApp(
          home: VaccinationPassportScreen(
            repository: LocalVaccinationRepository(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sổ Tiêm Chủng & Hộ Chiếu Vắc-Xin'), findsOneWidget);
      expect(find.textContaining('Sổ tiêm (4)'), findsOneWidget);
      expect(find.text('Hộ chiếu vắc-xin'), findsOneWidget);
      expect(find.text('Phác đồ chuẩn'), findsOneWidget);

      // Verify upcoming reminder countdown banner
      expect(find.text('LỊCH HẸN TIÊM CHỦNG SẮP TỚI'), findsOneWidget);
      expect(find.text('1 chạm Đặt lịch tiêm chủng tại viện'), findsOneWidget);

      // Verify records are shown
      expect(find.text('Gardasil 9 (Mỹ)'), findsOneWidget);
      expect(find.text('Vaxigrip Tetra (Pháp)'), findsOneWidget);

      // Switch to Passport tab
      await tester.tap(find.text('Hộ chiếu vắc-xin'));
      await tester.pumpAndSettle();
      expect(find.text('CHỨNG NHẬN TIÊM CHỦNG ĐIỆN TỬ'), findsWidgets);

      // Switch to Protocols tab
      await tester.tap(find.text('Phác đồ chuẩn'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Phác đồ tiêm chủng quốc gia'), findsOneWidget);
    });

    testWidgets('AddVaccinationScreen populates template and saves dose', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AddVaccinationScreen(
            patientName: 'Nguyễn Văn An',
            familyMemberId: 'fam-self',
            repository: LocalVaccinationRepository(),
          ),
        ),
      );

      expect(find.text('Thêm Mũi Tiêm Vắc-Xin'), findsOneWidget);

      // Tap quick template for Prevenar 13
      final prevenarChip = find.text('Prevenar 13 (Mỹ)');
      expect(prevenarChip, findsOneWidget);
      await tester.tap(prevenarChip);
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.text('Lưu Vào Sổ & Cấp Hộ Chiếu Vắc-Xin');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Check store has Prevenar 13
      final records = VaccinationStore.instance.records;
      expect(records.any((r) => r.vaccineName.contains('Prevenar 13')), true);
    });
  });
}
