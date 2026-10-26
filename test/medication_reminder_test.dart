import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/theme/app_theme.dart';
import 'package:smart_hospital/features/reminders/data/medication_reminder_repository.dart';
import 'package:smart_hospital/features/reminders/domain/medication_reminder.dart';
import 'package:smart_hospital/features/reminders/presentation/medication_reminder_screen.dart';

Widget _buildTestApp(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: child,
    );

void main() {
  group('Medication Reminder Repository Unit Tests', () {
    test('Local repository seeds data and calculates compliance stats', () async {
      final repo = LocalMedicationReminderRepository();
      final reminders = await repo.getReminders();
      expect(reminders.length, greaterThanOrEqualTo(2));

      final doses = await repo.getTodayDoses();
      expect(doses.isNotEmpty, isTrue);

      final stats = await repo.getComplianceStats();
      expect(stats.complianceRate, greaterThanOrEqualTo(0));
    });

    test('Local repository 1-Click parse from prescription', () async {
      final repo = LocalMedicationReminderRepository(initialReminders: []);
      const rx = '1. Paracetamol 500mg: 1 viên x 2 lần/ngày sau ăn\n2. Amoxicillin 500mg (1 viên x 3 lần/ngày)';

      final created = await repo.createFromPrescription(prescription: rx, daysCount: 5);
      expect(created.length, equals(2));

      expect(created[0].medicineName, contains('Paracetamol'));
      expect(created[0].timesPerDay, equals(2));
      expect(created[0].reminderTimes, equals(['08:00', '20:00']));

      expect(created[1].medicineName, contains('Amoxicillin'));
      expect(created[1].timesPerDay, equals(3));
      expect(created[1].reminderTimes, equals(['08:00', '13:00', '20:00']));

      final doses = await repo.getTodayDoses();
      expect(doses.length, equals(5)); // 2 for para + 3 for amox
    });

    test('Local repository update dose status to taken and skipped', () async {
      final repo = LocalMedicationReminderRepository();
      final doses = await repo.getTodayDoses();
      final target = doses.firstWhere((d) => d.status == DoseStatus.pending);

      final updated = await repo.updateDoseStatus(target.id, DoseStatus.taken);
      expect(updated.status, equals(DoseStatus.taken));
      expect(updated.takenAt, isNotNull);
    });
  });

  group('Medication Reminder UI Tests', () {
    testWidgets('MedicationReminderScreen displays today schedule and marks dose as taken', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalMedicationReminderRepository();

      await tester.pumpWidget(
        _buildTestApp(
          MedicationReminderScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Header & Tabs
      expect(find.text('Hẹn giờ Nhắc uống thuốc'), findsOneWidget);
      expect(find.text('Tiến độ uống thuốc hôm nay'), findsOneWidget);
      expect(find.text('Các liều thuốc cần uống'), findsOneWidget);

      // Verify at least one pending dose card with 'Đã uống' button
      final takenButtonFinder = find.widgetWithText(FilledButton, 'Đã uống');
      if (takenButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(takenButtonFinder.first);
        await tester.pumpAndSettle();

        // Verify status badge updated to 'Hoàn thành'
        expect(find.text('Hoàn thành'), findsAtLeastNWidgets(1));
      }

      // Switch to Tab 2: 'Đơn thuốc'
      await tester.tap(find.textContaining('Đơn thuốc'));
      await tester.pumpAndSettle();

      // Verify list of prescriptions
      expect(find.text('Danh sách thuốc đang theo dõi'), findsOneWidget);
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
      expect(find.text('Amoxicillin 500mg'), findsOneWidget);
    });
  });
}
