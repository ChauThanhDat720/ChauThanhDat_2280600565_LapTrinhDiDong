import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/theme/app_theme.dart';
import 'package:smart_hospital/features/notifications/data/notification_store.dart';
import 'package:smart_hospital/features/notifications/presentation/notification_screen.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: child,
  );
}

void main() {
  testWidgets('NotificationScreen displays notification items', (tester) async {
    final store = NotificationStore.instance;

    await tester.pumpWidget(_buildTestApp(const NotificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Bác sĩ đã xác nhận lịch khám'), findsOneWidget);
    expect(find.text('Đã có kết quả khám & Đơn thuốc'), findsOneWidget);
    expect(find.text('Nhắc nhở uống thuốc'), findsOneWidget);

    if (store.unreadCount > 0) {
      expect(find.text('Đọc tất cả'), findsOneWidget);
      await tester.tap(find.text('Đọc tất cả'));
      await tester.pumpAndSettle();
      expect(store.unreadCount, 0);
    }
  });

  testWidgets('Tapping a notification shows detail dialog', (tester) async {
    await tester.pumpWidget(_buildTestApp(const NotificationScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bác sĩ đã xác nhận lịch khám'));
    await tester.pumpAndSettle();

    expect(find.text('Đóng'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    expect(find.text('Đóng'), findsNothing);
  });
}
