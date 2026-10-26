import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/theme/app_theme.dart';
import 'package:smart_hospital/features/vitals/data/health_vitals_repository.dart';
import 'package:smart_hospital/features/vitals/domain/health_vital.dart';
import 'package:smart_hospital/features/vitals/presentation/health_vitals_screen.dart';
import 'package:smart_hospital/features/vitals/presentation/record_vital_dialog.dart';

Widget _buildTestApp(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: child,
    );

void main() {
  group('Health Vitals Repository Unit Tests', () {
    test('Local repository seeds data and calculates summary correctly', () async {
      final repo = LocalHealthVitalsRepository();
      final history = await repo.getVitalsHistory();
      expect(history.length, equals(7));

      final latest = await repo.getLatestVital();
      expect(latest, isNotNull);
      expect(latest!.systolic, equals(118));
      expect(latest.diastolic, equals(78));

      final summary = await repo.getVitalsSummary();
      expect(summary.totalRecords, equals(7));
      expect(summary.avgSystolic, isNotNull);
      expect(summary.avgDiastolic, isNotNull);
      expect(summary.dangerCount, equals(2)); // Days 9 and 7 were stage 1 hypertension
    });

    test('Local repository records new vital with BMI & WHO evaluation', () async {
      final repo = LocalHealthVitalsRepository(initialVitals: []);

      final vital = HealthVital(
        id: '',
        patientId: 'pat-test',
        systolic: 150,
        diastolic: 95,
        heartRate: 85,
        bloodSugar: 6.0,
        weight: 70.0,
        height: 175.0,
        recordedAt: DateTime.now(),
      );

      final saved = await repo.recordVital(vital);
      expect(saved.systolic, equals(150));
      expect(saved.diastolic, equals(95));
      expect(saved.bmi, equals(22.9)); // 70 / (1.75^2) = 22.857 -> 22.9
      expect(saved.healthStatus, equals('danger'));
      expect(saved.bpCategory, equals(BloodPressureCategory.hypertensionStage1));

      final history = await repo.getVitalsHistory();
      expect(history.length, equals(1));
    });

    test('Local repository deletes vital', () async {
      final repo = LocalHealthVitalsRepository();
      final list = await repo.getVitalsHistory();
      final target = list.first;

      await repo.deleteVital(target.id);
      final updated = await repo.getVitalsHistory();
      expect(updated.length, equals(6));
    });
  });

  group('Health Vitals UI Tests', () {
    testWidgets('HealthVitalsScreen renders overview banner, trend chart, and history list', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalHealthVitalsRepository();

      await tester.pumpWidget(
        _buildTestApp(
          HealthVitalsScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Header & latest vitals banner
      expect(find.text('Chỉ số Sinh hiệu & Sức khỏe'), findsOneWidget);
      expect(find.text('Chỉ số sinh hiệu mới nhất'), findsOneWidget);
      expect(find.text('118/78'), findsOneWidget);
      expect(find.text('Huyết áp tối ưu'), findsAtLeastNWidgets(1));

      // Trend chart title & toggle
      expect(find.text('Biểu đồ theo dõi xu hướng'), findsOneWidget);
      expect(find.text('Huyết áp'), findsAtLeastNWidgets(1));

      // History section
      expect(find.text('Lịch sử đo gần đây'), findsOneWidget);
      expect(find.text('7 lần đo'), findsOneWidget);

      // Tap FAB "Ghi nhận chỉ số"
      await tester.tap(find.text('Ghi nhận chỉ số'));
      await tester.pumpAndSettle();

      // Verify RecordVitalDialog opened
      expect(find.byType(RecordVitalDialog), findsOneWidget);
      expect(find.text('Ghi nhận Chỉ số Sinh hiệu'), findsOneWidget);
      expect(find.text('Lưu Chỉ Số Sinh Hiệu'), findsOneWidget);
    });

    testWidgets('HealthVitalsScreen displays doctor view title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalHealthVitalsRepository();

      await tester.pumpWidget(
        _buildTestApp(
          HealthVitalsScreen(repository: repo, isDoctorView: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sinh hiệu Bệnh nhân'), findsOneWidget);
    });
  });
}
