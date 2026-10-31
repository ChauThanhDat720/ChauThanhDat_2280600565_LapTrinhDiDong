import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/realtime/hospital_realtime_service.dart';
import 'package:smart_hospital/core/realtime/realtime_events.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/notifications/data/notification_store.dart';
import 'package:smart_hospital/features/teleconsultation/domain/teleconsultation.dart';
import 'package:smart_hospital/features/vitals/domain/health_vital.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HospitalRealtimeService Tests', () {
    test('Queue Call stream & Notification auto-dispatch', () async {
      final service = HospitalRealtimeService.instance;
      final initialNotifs = NotificationStore.instance.items.length;

      RealtimeQueueEvent? receivedEvent;
      final sub = service.queueStream.listen((event) {
        receivedEvent = event;
      });

      service.notifyQueueCalled(
        appointmentId: 'apt-test-1',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        patientName: 'Nguyễn Văn An',
        queueNumber: 5,
        roomNumber: 'Phòng 204',
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.type, equals(RealtimeEventType.queueCalled));
      expect(receivedEvent!.queueNumber, equals(5));
      expect(receivedEvent!.patientName, equals('Nguyễn Văn An'));

      // Kiểm tra xem đã tự động tạo thông báo real-time chưa
      expect(NotificationStore.instance.items.length, greaterThan(initialNotifs));
      expect(NotificationStore.instance.items.first.title, contains('STT: 05'));

      await sub.cancel();
    });

    test('Chat message stream & Doctor notification', () async {
      final service = HospitalRealtimeService.instance;

      RealtimeChatMessageEvent? receivedChat;
      final sub = service.chatStream.listen((event) {
        receivedChat = event;
      });

      final msg = TeleconsultationMessage(
        id: 'msg-test-1',
        sessionId: 'sess-1',
        senderType: MessageSenderType.doctor,
        senderId: 'dr-linh',
        senderName: 'BS. Trần Thảo Linh',
        message: 'Bạn uống thuốc đều đặn nhé!',
        createdAt: DateTime.now(),
      );

      service.notifyChatMessage(
        sessionId: 'sess-1',
        appointmentId: 'apt-1',
        message: msg,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedChat, isNotNull);
      expect(receivedChat!.message.message, equals('Bạn uống thuốc đều đặn nhé!'));

      await sub.cancel();
    });

    test('VietQR payment confirmation real-time stream', () async {
      final service = HospitalRealtimeService.instance;

      RealtimePaymentEvent? receivedPayment;
      final sub = service.paymentStream.listen((event) {
        receivedPayment = event;
      });

      service.notifyPaymentConfirmed(
        invoiceId: 'inv-101',
        appointmentId: 'apt-101',
        invoiceCode: 'HD101',
        amount: 150000,
        bankTransactionId: 'MB-TEST999',
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedPayment, isNotNull);
      expect(receivedPayment!.invoiceId, equals('inv-101'));
      expect(receivedPayment!.amount, equals(150000));
      expect(receivedPayment!.bankTransactionId, equals('MB-TEST999'));

      await sub.cancel();
    });

    test('Vital alert triggered real-time notification', () async {
      final service = HospitalRealtimeService.instance;
      final initialNotifs = NotificationStore.instance.items.length;

      final vital = HealthVital(
        id: 'vit-test-1',
        patientId: 'patient-1',
        systolic: 165,
        diastolic: 105,
        heartRate: 130,
        healthStatus: 'danger',
        recordedAt: DateTime.now(),
      );

      service.notifyVitalUpdate(
        patientId: 'patient-1',
        vital: vital,
        isAlert: true,
        alertMessage: 'CẢNH BÁO: Tăng huyết áp cấp tính (165/105 mmHg)',
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(NotificationStore.instance.items.length, greaterThan(initialNotifs));
      expect(NotificationStore.instance.items.first.title, contains('CẢNH BÁO SINH TỒN'));
    });
  });
}
