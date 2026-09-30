import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/app.dart';

void main() {
  testWidgets('shows the Smart Hospital splash screen', (tester) async {
    await tester.pumpWidget(const SmartHospitalApp());
    expect(find.text('Smart Hospital'), findsOneWidget);
  });
}
