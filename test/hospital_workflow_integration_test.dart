import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/appointments/presentation/appointment_list_screen.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_dashboard_screen.dart';
import 'package:smart_hospital/features/notifications/data/notification_store.dart';
import 'package:smart_hospital/features/notifications/domain/notification_item.dart';
import 'package:smart_hospital/features/payments/domain/invoice.dart';
import 'package:smart_hospital/features/payments/presentation/e_invoice_screen.dart';

class _MockWorkflowAppointmentRepository implements AppointmentRepository {
  _MockWorkflowAppointmentRepository(this.items);

  List<Appointment> items;
  DateTime? lastFollowUpDate;

  @override
  Future<List<Appointment>> getDoctorAppointments({
    String? doctorId,
    DateTime? date,
  }) async =>
      items;

  @override
  Future<List<Appointment>> getMyAppointments() async => items;

  @override
  Future<List<Appointment>> getAppointments() async => items;

  @override
  Future<Appointment?> getAppointmentById(String id) async =>
      items.where((x) => x.id == id).firstOrNull;

  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) async {
    final idx = items.indexWhere((a) => a.id == id);
    final updated = items[idx].copyWith(status: AppointmentStatus.cancelled);
    items[idx] = updated;
    return updated;
  }

  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) async =>
      items.first;

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async =>
      items.first;

  @override
  Future<Appointment> updateAppointmentStatus(
    String id,
    AppointmentStatus status, {
    String? note,
    String? diagnosis,
    String? prescription,
    DateTime? followUpDate,
  }) async {
    lastFollowUpDate = followUpDate;
    final idx = items.indexWhere((a) => a.id == id);
    final updated = items[idx].copyWith(
      status: status,
      statusNote: note,
      diagnosis: diagnosis,
      prescription: prescription,
      followUpDate: followUpDate,
      updatedAt: DateTime(2026, 11, 20),
    );
    items[idx] = updated;
    return updated;
  }

  @override
  Future<List<AppointmentSlot>> getAvailableSlots(
    String doctorId,
    DateTime selectedDate,
  ) async =>
      [
        AppointmentSlot(
          startTime: DateTime(2026, 11, 20, 8, 30),
          endTime: DateTime(2026, 11, 20, 9, 0),
          isAvailable: true,
        ),
      ];

  @override
  Future<Appointment> createAppointment(Appointment appointment) async =>
      appointment;
}

void main() {
  setUp(() {
    AppointmentStore.instance.clearForTest();
  });

  group('Doctor & Patient Integrated Hospital Workflow Tests', () {
    testWidgets(
        'Doctor views patient medical history and follow-up chips are rendered in Consultation Dialog',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed past visit in AppointmentStore
      AppointmentStore.instance.addAppointment(
        Appointment(
          id: 'PAST-01',
          patientId: 'patient-nguyen-van-a',
          patientName: 'Nguyễn Văn A',
          doctorId: 'dr-linh',
          doctorName: 'BS. Trần Thảo Linh',
          specialty: 'Tim mạch',
          department: 'Tim mạch',
          date: DateTime(2026, 10, 1),
          time: '09:00',
          reason: 'Tức ngực khó thở',
          status: AppointmentStatus.completed,
          diagnosis: 'Cơn đau thắt ngực ổn định',
          prescription: '1. Nitroglycerin 0.4mg ngậm dưới lưỡi\n2. Aspirin 81mg',
          statusNote: 'Hạn chế vận động gắng sức',
        ),
      );

      final currentApt = Appointment(
        id: 'APT-CURRENT',
        patientId: 'patient-nguyen-van-a',
        patientName: 'Nguyễn Văn A',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Tim mạch',
        department: 'Tim mạch',
        date: DateTime.now(),
        time: '10:00',
        reason: 'Tái khám định kỳ theo hẹn',
        status: AppointmentStatus.confirmed,
      );

      final repo = _MockWorkflowAppointmentRepository([currentApt]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorExaminationScreen(
              appointment: currentApt,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Patient Medical History Button
      expect(
        find.text('Xem lịch sử khám & đơn thuốc cũ của bệnh nhân'),
        findsOneWidget,
      );

      // Tap to open Medical History Bottom Sheet
      await tester.tap(find.text('Xem lịch sử khám & đơn thuốc cũ của bệnh nhân'));
      await tester.pumpAndSettle();

      // Verify past history is displayed
      expect(find.textContaining('LỊCH SỬ BỆNH ÁN CŨ'), findsOneWidget);
      expect(find.textContaining('Cơn đau thắt ngực ổn định'), findsOneWidget);
      expect(find.text('Kê lại đơn thuốc này'), findsOneWidget);

      // Re-prescribe 1-click
      await tester.tap(find.text('Kê lại đơn thuốc này'));
      await tester.pumpAndSettle();

      // Verify prescription text field populated
      expect(
        find.textContaining('Nitroglycerin 0.4mg'),
        findsOneWidget,
      );

      // Check Follow-up section chips
      expect(find.text('Kế hoạch Hẹn ngày Tái khám'), findsOneWidget);
      expect(find.text('7 ngày nữa'), findsOneWidget);
      expect(find.text('14 ngày nữa'), findsOneWidget);
      expect(find.text('1 tháng nữa'), findsOneWidget);

      // Select 14-day chip
      await tester.tap(find.text('14 ngày nữa'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Bác sĩ đặt lịch hẹn tái khám:'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Patient views follow-up banner on completed appointment and opens prefilled booking screen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final followUpDate = DateTime.now().add(const Duration(days: 14));
      final completedApt = Appointment(
        id: 'APT-COMPLETED',
        patientId: 'patient-nguyen-van-a',
        patientName: 'Nguyễn Văn A',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        specialty: 'Tim mạch',
        department: 'Tim mạch',
        date: DateTime.now(),
        time: '08:30',
        reason: 'Đau thắt ngực',
        status: AppointmentStatus.completed,
        diagnosis: 'Tăng huyết áp vô căn',
        prescription: '1. Amlodipine 5mg',
        statusNote: 'Ăn nhạt, tái khám sau 2 tuần',
        followUpDate: followUpDate,
      );

      final repo = _MockWorkflowAppointmentRepository([completedApt]);

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: completedApt,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Follow-up reminder banner
      expect(find.textContaining('Hẹn tái khám:'), findsOneWidget);
      expect(find.text('Đặt lịch tái khám ngay theo hẹn'), findsOneWidget);

      await tester.ensureVisible(find.text('Đặt lịch tái khám ngay theo hẹn'));
      await tester.pumpAndSettle();

      // Tap 1-tap booking button
      await tester.tap(find.text('Đặt lịch tái khám ngay theo hẹn'));
      await tester.pumpAndSettle();

      // Verify navigated to BookAppointmentScreen with prefilled reason
      expect(find.text('Đặt lịch khám'), findsOneWidget);
      expect(find.textContaining('Tái khám theo hẹn:'), findsOneWidget);
    });

    testWidgets(
        'EInvoiceScreen displays live hospital pharmacy dispensing progress (3 steps)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final invoice = Invoice(
        id: 'INV-PHARMACY-TEST',
        appointmentId: 'APT-01',
        patientId: 'PAT-01',
        patientName: 'Nguyễn Văn A',
        invoiceCode: 'HD-20261025-001',
        examinationFee: 150000,
        medicineFee: 120000,
        otherFee: 0,
        discountAmount: 0,
        totalAmount: 270000,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: 'VietQR',
        paymentRef: 'VQR-001',
        bankName: 'MB Bank',
        bankBin: '970422',
        bankAccountNumber: '0388998839',
        bankAccountName: 'BENH VIEN DA KHOA THONG MINH',
        paidAmount: 270000,
        paidAt: DateTime.now(),
        items: const [
          InvoiceItem(
            name: 'Amlodipine 5mg',
            category: 'Thuốc điều trị',
            unit: 'Viên',
            quantity: 30,
            unitPrice: 2000,
          ),
          InvoiceItem(
            name: 'Aspirin 81mg',
            category: 'Thuốc tim mạch',
            unit: 'Viên',
            quantity: 30,
            unitPrice: 2000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EInvoiceScreen(invoice: invoice),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Section IV and Pharmacy tracking
      expect(
        find.text('IV. TIẾN ĐỘ CẤP PHÁT THUỐC TẠI NHÀ THUỐC BỆNH VIỆN'),
        findsOneWidget,
      );
      expect(
        find.text('Quầy Dược số 2 - Tầng 1 (Khu khám Ngoại trú)'),
        findsOneWidget,
      );
      expect(find.text('ĐÃ SẴN SÀNG'), findsOneWidget);
      expect(find.text('Bác sĩ kê đơn điện tử'), findsOneWidget);
      expect(find.text('Đã hoàn tất thanh toán viện phí'), findsOneWidget);
      expect(find.text('Thuốc đã soạn sẵn sàng'), findsOneWidget);
    });

    test('NotificationStore receives notifications on doctor calls & payment', () {
      final notifStore = NotificationStore.instance;
      final initialCount = notifStore.items.length;

      // Doctor calls patient into examination room
      notifStore.addNotification(
        title: 'Mời vào phòng khám',
        body: 'Mời bệnh nhân Nguyễn Văn A (STT: 05) vào Phòng khám Tim mạch.',
        type: NotificationType.appointment,
        referenceId: 'APT-101',
      );

      // Doctor completes examination
      notifStore.addNotification(
        title: 'Đã hoàn tất ca khám & Kê đơn thuốc',
        body: 'Bác sĩ đã hoàn tất kết luận bệnh án. Toa thuốc đã được kê điện tử.',
        type: NotificationType.prescription,
        referenceId: 'APT-101',
      );

      // Payment completed
      notifStore.addNotification(
        title: 'Thanh toán viện phí thành công',
        body: 'Giao dịch cho hóa đơn INV-101 đã hoàn tất.',
        type: NotificationType.system,
        referenceId: 'INV-101',
      );

      expect(notifStore.items.length, initialCount + 3);
      expect(notifStore.items[0].title, 'Thanh toán viện phí thành công');
      expect(notifStore.items[1].title, 'Đã hoàn tất ca khám & Kê đơn thuốc');
      expect(notifStore.items[2].title, 'Mời vào phòng khám');
    });
  });
}
