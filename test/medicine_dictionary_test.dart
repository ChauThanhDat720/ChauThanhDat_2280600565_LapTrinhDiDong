import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/theme/app_theme.dart';
import 'package:smart_hospital/features/medicines/data/medicine_repository.dart';
import 'package:smart_hospital/features/medicines/presentation/medicine_detail_screen.dart';
import 'package:smart_hospital/features/medicines/presentation/medicine_list_screen.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/medical_records/presentation/medical_records_screen.dart';

void main() {
  const repository = LocalMedicineRepository();

  Widget testApp(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: child,
      );

  group('Medicine Repository Tests', () {
    test('getMedicines returns full list of catalog drugs', () async {
      final list = await repository.getMedicines();
      expect(list.length, greaterThanOrEqualTo(10));
      expect(list.any((m) => m.name == 'Paracetamol'), isTrue);
      expect(list.any((m) => m.name == 'Amlodipine'), isTrue);
    });

    test('getMedicines filters by category', () async {
      final list = await repository.getMedicines(category: 'Kháng sinh');
      expect(list.length, greaterThanOrEqualTo(1));
      expect(list.every((m) => m.category == 'Kháng sinh'), isTrue);
    });

    test('getMedicines searches by brand name and active ingredient', () async {
      final byBrand = await repository.getMedicines(search: 'Panadol');
      expect(byBrand.any((m) => m.name == 'Paracetamol'), isTrue);

      final byActive = await repository.getMedicines(search: 'Ventolin');
      expect(byActive.any((m) => m.name == 'Salbutamol'), isTrue);
    });

    test('lookupByName matches prescription strings', () async {
      final match1 = await repository.lookupByName('Panadol 500mg x 10 viên');
      expect(match1, isNotNull);
      expect(match1!.name, 'Paracetamol');

      final match2 = await repository.lookupByName('Aspirin 81mg - 1 viên/ngày sau ăn');
      expect(match2, isNotNull);
      expect(match2!.name, 'Aspirin 81mg');
    });

    test('getCategories returns distinct category list', () async {
      final categories = await repository.getCategories();
      expect(categories, contains('Giảm đau - Hạ sốt'));
      expect(categories, contains('Tim mạch - Huyết áp'));
      expect(categories, contains('Kháng sinh'));
    });
  });

  group('Medicine UI Tests', () {
    testWidgets('MedicineListScreen renders search bar, category chips, and medicine cards', (tester) async {
      await tester.pumpWidget(testApp(const MedicineListScreen(repository: repository)));
      await tester.pumpAndSettle();

      expect(find.text('Từ điển Dược phẩm'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);
      expect(find.text('Amlodipine'), findsOneWidget);

      // Search interaction
      await tester.enterText(find.byType(TextField), 'Amoxicillin');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Card, 'Amoxicillin'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Paracetamol'), findsNothing);
    });

    testWidgets('MedicineDetailScreen displays complete clinical monograph', (tester) async {
      final amlodipine = (await repository.getMedicineById('med-amlodipine'))!;

      await tester.pumpWidget(testApp(MedicineDetailScreen(medicine: amlodipine)));
      await tester.pumpAndSettle();

      expect(find.text('Amlodipine'), findsWidgets);
      expect(find.text('Amlodipine besylate 5mg'), findsOneWidget);
      expect(find.text('Chỉ định & Công dụng điều trị'), findsOneWidget);
      expect(find.text('Liều dùng & Cách dùng chuẩn'), findsOneWidget);
      expect(find.text('Tác dụng phụ thường gặp & Nguy cơ'), findsOneWidget);
      expect(find.text('Chống chỉ định (Tuyệt đối không dùng)'), findsOneWidget);
      expect(find.text('Thận trọng & Dặn dò y tế'), findsOneWidget);
    });

    testWidgets('Tapping Xem HDSD in MedicalRecordsScreen navigates to MedicineDetailScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appointment = Appointment(
        id: 'APT-TEST',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Tim mạch',
        specialty: 'Tim mạch',
        date: DateTime(2026, 11, 20),
        time: '09:00',
        reason: 'Khám tim',
        status: AppointmentStatus.completed,
        diagnosis: 'Rối loạn nhịp tim',
        prescription: 'Panadol 500mg x 10 viên',
      );

      final recordRepo = _MockRecordRepo([appointment]);

      await tester.pumpWidget(testApp(MedicalRecordsScreen(repository: recordRepo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Xem HDSD: Panadol'), findsOneWidget);

      await tester.tap(find.textContaining('Xem HDSD: Panadol'));
      await tester.pumpAndSettle();

      // Successfully navigated to MedicineDetailScreen for Paracetamol
      expect(find.byType(MedicineDetailScreen), findsOneWidget);
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
    });
  });
}

class _MockRecordRepo implements AppointmentRepository {
  _MockRecordRepo(this.items);
  final List<Appointment> items;

  @override
  Future<List<Appointment>> getMyAppointments() async => items;
  @override
  Future<List<Appointment>> getAppointments() => getMyAppointments();
  @override
  Future<List<AppointmentSlot>> getAvailableSlots(String doctorId, DateTime date) async => [];
  @override
  Future<Appointment> createAppointment(Appointment appointment) async => appointment;
  @override
  Future<Appointment?> getAppointmentById(String id) async => items.firstOrNull;
  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) async => items.first;
  @override
  Future<List<Appointment>> getDoctorAppointments({String? doctorId, DateTime? date, AppointmentStatus? status}) async => items;
  @override
  Future<Appointment> updateAppointmentStatus(String id, AppointmentStatus status, {String? note, String? diagnosis, String? prescription, DateTime? followUpDate}) async => items.first;
  @override
  Future<Appointment> rateAppointment(String id, {required int rating, String? reviewNote}) async => items.first;
  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) async => items.first;
}

