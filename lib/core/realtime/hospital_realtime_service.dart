import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/appointments/domain/appointment.dart';
import '../../features/notifications/data/notification_store.dart';
import '../../features/notifications/domain/notification_item.dart';
import '../../features/payments/domain/invoice.dart';
import '../../features/teleconsultation/domain/teleconsultation.dart';
import '../../features/vitals/domain/health_vital.dart';
import '../network/api_config.dart';
import 'realtime_events.dart';

/// Dịch vụ thời gian thực tập trung cho toàn bộ ứng dụng Smart Hospital
class HospitalRealtimeService {
  HospitalRealtimeService._();
  static final HospitalRealtimeService instance = HospitalRealtimeService._();

  final StreamController<RealtimeQueueEvent> _queueController =
      StreamController<RealtimeQueueEvent>.broadcast();
  final StreamController<RealtimeChatMessageEvent> _chatController =
      StreamController<RealtimeChatMessageEvent>.broadcast();
  final StreamController<RealtimePaymentEvent> _paymentController =
      StreamController<RealtimePaymentEvent>.broadcast();
  final StreamController<RealtimeVitalEvent> _vitalsController =
      StreamController<RealtimeVitalEvent>.broadcast();

  Stream<RealtimeQueueEvent> get queueStream => _queueController.stream;
  Stream<RealtimeChatMessageEvent> get chatStream => _chatController.stream;
  Stream<RealtimePaymentEvent> get paymentStream => _paymentController.stream;
  Stream<RealtimeVitalEvent> get vitalsStream => _vitalsController.stream;

  http.Client? _sseClient;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _currentBaseUrl;

  /// Khởi chạy kết nối real-time SSE nếu có backend endpoint
  Future<void> connect({String? baseUrl}) async {
    final targetUrl = baseUrl ?? ApiConfig().baseUrl;
    if (targetUrl.isEmpty) {
      _isConnected = true;
      return;
    }
    _currentBaseUrl = targetUrl;
    _startSseListener(targetUrl);
  }

  void _startSseListener(String baseUrl) async {
    try {
      _sseClient?.close();
      _sseClient = http.Client();
      final streamUri = Uri.parse('$baseUrl/api/realtime/stream');
      final request = http.Request('GET', streamUri);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _sseClient!.send(request);
      if (response.statusCode == 200) {
        _isConnected = true;
        response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              _handleSseLine,
              onError: (err) {
                _isConnected = false;
                _scheduleReconnect();
              },
              onDone: () {
                _isConnected = false;
                _scheduleReconnect();
              },
            );
      }
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_currentBaseUrl != null && _currentBaseUrl!.isNotEmpty) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!_isConnected && _currentBaseUrl != null) {
          connect(baseUrl: _currentBaseUrl);
        }
      });
    }
  }

  void _handleSseLine(String line) {
    if (line.startsWith('data: ')) {
      final jsonStr = line.substring(6).trim();
      if (jsonStr.isEmpty) return;
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final eventCategory = data['category'] as String?;
        final payload = data['payload'] as Map<String, dynamic>? ?? {};

        switch (eventCategory) {
          case 'appointment_created':
            final aptData = payload['appointment'] as Map<String, dynamic>?;
            final eventData = payload['event'] as Map<String, dynamic>? ?? payload;
            final aEvent = RealtimeQueueEvent.fromJson(eventData);
            _queueController.add(aEvent);
            if (aptData != null) {
              final apt = Appointment.fromJson(aptData);
              _handleAppointmentCreatedNotification(apt);
            }
            break;
          case 'queue':
            final qEvent = RealtimeQueueEvent.fromJson(payload);
            _queueController.add(qEvent);
            _handleQueueNotification(qEvent);
            break;
          case 'chat':
            final cEvent = RealtimeChatMessageEvent.fromJson(payload);
            _chatController.add(cEvent);
            _handleChatNotification(cEvent);
            break;
          case 'payment':
            final pEvent = RealtimePaymentEvent.fromJson(payload);
            _paymentController.add(pEvent);
            _handlePaymentNotification(pEvent);
            break;
          case 'vital':
            // Xử lý vitals
            break;
        }
      } catch (err) {
        debugPrint('Lỗi giải mã SSE: $err');
      }
    }
  }

  // ==================== DISPATCH / BROADCAST METHODS ====================

  /// Thông báo có ca khám mới được tạo cho bác sĩ (Real-time Appointment Notification)
  void notifyAppointmentCreated(Appointment appointment) {
    final event = RealtimeQueueEvent(
      type: RealtimeEventType.appointmentCreated,
      appointmentId: appointment.id,
      doctorId: appointment.doctorId,
      doctorName: appointment.doctorName,
      patientName: appointment.patientName,
      queueNumber: appointment.queueNumber ?? 1,
      roomNumber: appointment.roomNumber ?? 'Phòng khám ${appointment.specialty}',
      status: appointment.status,
      note: 'Lịch khám lúc ${appointment.time} ngày ${appointment.date.day}/${appointment.date.month} (Lý do: ${appointment.reason})',
      timestamp: DateTime.now(),
    );
    _queueController.add(event);
    _handleAppointmentCreatedNotification(appointment);
    _broadcastToBackend('appointment_created', {
      'appointment': appointment.toJson(),
      'event': event.toJson(),
    });
  }

  /// Bác sĩ gọi số khám bệnh nhân tiếp theo (Real-time Calling)
  void notifyQueueCalled({
    required String appointmentId,
    required String doctorId,
    required String doctorName,
    required String patientName,
    required int queueNumber,
    required String roomNumber,
    String? note,
  }) {
    final event = RealtimeQueueEvent(
      type: RealtimeEventType.queueCalled,
      appointmentId: appointmentId,
      doctorId: doctorId,
      doctorName: doctorName,
      patientName: patientName,
      queueNumber: queueNumber,
      roomNumber: roomNumber,
      status: AppointmentStatus.inProgress,
      note: note,
      timestamp: DateTime.now(),
    );
    _queueController.add(event);
    _handleQueueNotification(event);
    _broadcastToBackend('queue', event.toJson());
  }

  /// Bệnh nhân hoặc lễ tân thực hiện Check-in tiếp đón thành công
  void notifyPatientCheckin({
    required String appointmentId,
    required String doctorId,
    required String doctorName,
    required String patientName,
    required int queueNumber,
    required String roomNumber,
  }) {
    final event = RealtimeQueueEvent(
      type: RealtimeEventType.patientCheckin,
      appointmentId: appointmentId,
      doctorId: doctorId,
      doctorName: doctorName,
      patientName: patientName,
      queueNumber: queueNumber,
      roomNumber: roomNumber,
      status: AppointmentStatus.checkedIn,
      timestamp: DateTime.now(),
    );
    _queueController.add(event);
    _handleQueueNotification(event);
    _broadcastToBackend('queue', event.toJson());
  }

  /// Cập nhật trạng thái ca khám (Hoàn thành, đang khám, hủy)
  void notifyAppointmentStatus({
    required String appointmentId,
    required AppointmentStatus status,
    String? doctorId,
    String? doctorName,
    String? patientName,
    int? queueNumber,
    String? roomNumber,
    String? note,
  }) {
    final event = RealtimeQueueEvent(
      type: RealtimeEventType.appointmentStatusChanged,
      appointmentId: appointmentId,
      doctorId: doctorId ?? '',
      doctorName: doctorName ?? '',
      patientName: patientName ?? '',
      queueNumber: queueNumber ?? 0,
      roomNumber: roomNumber ?? '',
      status: status,
      note: note,
      timestamp: DateTime.now(),
    );
    _queueController.add(event);
    _broadcastToBackend('queue', event.toJson());
  }

  /// Gửi tin nhắn chat tư vấn trực tuyến (Real-time Messaging)
  void notifyChatMessage({
    required String sessionId,
    required String appointmentId,
    required TeleconsultationMessage message,
  }) {
    final event = RealtimeChatMessageEvent(
      sessionId: sessionId,
      appointmentId: appointmentId,
      message: message,
      timestamp: DateTime.now(),
    );
    _chatController.add(event);
    _handleChatNotification(event);
    _broadcastToBackend('chat', event.toJson());
  }

  /// Xác nhận thanh toán VietQR thành công theo thời gian thực
  void notifyPaymentConfirmed({
    required String invoiceId,
    required String appointmentId,
    required String invoiceCode,
    required int amount,
    required String bankTransactionId,
  }) {
    final event = RealtimePaymentEvent(
      invoiceId: invoiceId,
      appointmentId: appointmentId,
      invoiceCode: invoiceCode,
      amount: amount,
      bankTransactionId: bankTransactionId,
      paymentStatus: PaymentStatus.paid,
      timestamp: DateTime.now(),
    );
    _paymentController.add(event);
    _handlePaymentNotification(event);
    _broadcastToBackend('payment', event.toJson());
  }

  /// Phát tín hiệu chỉ số sinh tồn Telemetry thời gian thực
  void notifyVitalUpdate({
    required String patientId,
    required HealthVital vital,
    bool isAlert = false,
    String? alertMessage,
  }) {
    final event = RealtimeVitalEvent(
      patientId: patientId,
      vital: vital,
      isAlert: isAlert,
      alertMessage: alertMessage,
      timestamp: DateTime.now(),
    );
    _vitalsController.add(event);
    if (isAlert) {
      NotificationStore.instance.addNotification(
        title: '⚠️ CẢNH BÁO SINH TỒN BẤT THƯỜNG',
        body: alertMessage ??
            'Chỉ số sinh tồn của bạn bất thường (Huyết áp: ${vital.systolic}/${vital.diastolic} mmHg, Nhịp tim: ${vital.heartRate ?? "--"} bpm). Vui lòng nghỉ ngơi hoặc liên hệ hỗ trợ y tế!',
        type: NotificationType.system,
        referenceId: vital.id,
      );
    }
  }

  // ==================== NOTIFICATION DISPATCHERS ====================

  void _handleAppointmentCreatedNotification(Appointment appointment) {
    NotificationStore.instance.addNotification(
      title: '📅 ĐƠN KHÁM MỚI TỪ BỆNH NHÂN: ${appointment.patientName}',
      body: 'Bệnh nhân ${appointment.patientName} vừa đặt lịch khám với BS. ${appointment.doctorName} (${appointment.specialty}) lúc ${appointment.time} ngày ${appointment.date.day}/${appointment.date.month}/${appointment.date.year}. Lý do: ${appointment.reason}',
      type: NotificationType.appointment,
      referenceId: appointment.id,
    );
  }

  void _handleQueueNotification(RealtimeQueueEvent event) {
    if (event.type == RealtimeEventType.queueCalled) {
      NotificationStore.instance.addNotification(
        title: '🔔 ĐÃ ĐẾN LƯỢT KHÁM CỦA BẠN (STT: ${event.queueNumber.toString().padLeft(2, '0')})',
        body: 'Mời bệnh nhân ${event.patientName} vào ${event.roomNumber} gặp ${event.doctorName} để tiến hành khám bệnh.',
        type: NotificationType.appointment,
        referenceId: event.appointmentId,
      );
    } else if (event.type == RealtimeEventType.patientCheckin) {
      NotificationStore.instance.addNotification(
        title: '✅ Tiếp đón thành công (STT: ${event.queueNumber.toString().padLeft(2, '0')})',
        body: 'Bạn đã tiếp đón thành công tại ${event.roomNumber}. Vui lòng chờ đến số thứ tự của mình.',
        type: NotificationType.appointment,
        referenceId: event.appointmentId,
      );
    }
  }

  void _handleChatNotification(RealtimeChatMessageEvent event) {
    if (event.message.senderType == MessageSenderType.doctor) {
      NotificationStore.instance.addNotification(
        title: '💬 Tin nhắn mới từ ${event.message.senderName}',
        body: event.message.message,
        type: NotificationType.system,
        referenceId: event.appointmentId,
      );
    }
  }

  void _handlePaymentNotification(RealtimePaymentEvent event) {
    NotificationStore.instance.addNotification(
      title: '💳 Xác nhận thanh toán VietQR thành công',
      body: 'Giao dịch cho hóa đơn ${event.invoiceCode} (Mã GD: ${event.bankTransactionId}) số tiền ${_formatCurrency(event.amount)} đã được ghi nhận tức thì.',
      type: NotificationType.system,
      referenceId: event.invoiceId,
    );
  }

  String _formatCurrency(int amount) {
    final buffer = StringBuffer();
    final str = amount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()}đ';
  }

  Future<void> _broadcastToBackend(
    String category,
    Map<String, dynamic> payload,
  ) async {
    final baseUrl = _currentBaseUrl ?? ApiConfig().baseUrl;
    if (baseUrl.isEmpty) return;
    try {
      final uri = Uri.parse('$baseUrl/api/realtime/broadcast');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'category': category, 'payload': payload}),
      );
    } catch (_) {}
  }

  void dispose() {
    _sseClient?.close();
    _queueController.close();
    _chatController.close();
    _paymentController.close();
    _vitalsController.close();
  }
}
