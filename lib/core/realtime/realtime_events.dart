import 'package:flutter/foundation.dart';
import '../../features/appointments/domain/appointment.dart';
import '../../features/notifications/domain/notification_item.dart';
import '../../features/payments/domain/invoice.dart';
import '../../features/teleconsultation/domain/teleconsultation.dart';
import '../../features/vitals/domain/health_vital.dart';

/// Các loại sự kiện real-time trong bệnh viện
enum RealtimeEventType {
  appointmentCreated,
  queueCalled,
  patientCheckin,
  appointmentStatusChanged,
  chatMessageReceived,
  paymentConfirmed,
  vitalsUpdated,
  vitalAlertTriggered,
  locationUpdated,
  systemAlert,
}

/// Sự kiện hàng đợi khám bệnh real-time
@immutable
class RealtimeQueueEvent {
  const RealtimeQueueEvent({
    required this.type,
    required this.appointmentId,
    required this.doctorId,
    required this.doctorName,
    required this.patientName,
    required this.queueNumber,
    required this.roomNumber,
    this.status,
    this.note,
    required this.timestamp,
  });

  final RealtimeEventType type;
  final String appointmentId;
  final String doctorId;
  final String doctorName;
  final String patientName;
  final int queueNumber;
  final String roomNumber;
  final AppointmentStatus? status;
  final String? note;
  final DateTime timestamp;

  factory RealtimeQueueEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeQueueEvent(
      type: RealtimeEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RealtimeEventType.queueCalled,
      ),
      appointmentId: json['appointmentId'] as String? ?? '',
      doctorId: json['doctorId'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      queueNumber: json['queueNumber'] as int? ?? 1,
      roomNumber: json['roomNumber'] as String? ?? '',
      status: json['status'] != null
          ? AppointmentStatus.fromWire(json['status'] as String)
          : null,
      note: json['note'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'appointmentId': appointmentId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'patientName': patientName,
        'queueNumber': queueNumber,
        'roomNumber': roomNumber,
        'status': status?.wireName,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Sự kiện tin nhắn tư vấn từ xa real-time
@immutable
class RealtimeChatMessageEvent {
  const RealtimeChatMessageEvent({
    required this.sessionId,
    required this.appointmentId,
    required this.message,
    required this.timestamp,
  });

  final String sessionId;
  final String appointmentId;
  final TeleconsultationMessage message;
  final DateTime timestamp;

  factory RealtimeChatMessageEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeChatMessageEvent(
      sessionId: json['sessionId'] as String? ?? '',
      appointmentId: json['appointmentId'] as String? ?? '',
      message: TeleconsultationMessage.fromJson(
        json['message'] as Map<String, dynamic>? ?? {},
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'appointmentId': appointmentId,
        'message': message.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Sự kiện thanh toán VietQR real-time
@immutable
class RealtimePaymentEvent {
  const RealtimePaymentEvent({
    required this.invoiceId,
    required this.appointmentId,
    required this.invoiceCode,
    required this.amount,
    required this.bankTransactionId,
    required this.paymentStatus,
    required this.timestamp,
  });

  final String invoiceId;
  final String appointmentId;
  final String invoiceCode;
  final int amount;
  final String bankTransactionId;
  final PaymentStatus paymentStatus;
  final DateTime timestamp;

  factory RealtimePaymentEvent.fromJson(Map<String, dynamic> json) {
    return RealtimePaymentEvent(
      invoiceId: json['invoiceId'] as String? ?? '',
      appointmentId: json['appointmentId'] as String? ?? '',
      invoiceCode: json['invoiceCode'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      bankTransactionId: json['bankTransactionId'] as String? ?? '',
      paymentStatus: (json['paymentStatus'] == 'paid')
          ? PaymentStatus.paid
          : PaymentStatus.unpaid,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'invoiceId': invoiceId,
        'appointmentId': appointmentId,
        'invoiceCode': invoiceCode,
        'amount': amount,
        'bankTransactionId': bankTransactionId,
        'paymentStatus': paymentStatus.name,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Sự kiện chỉ số sinh tồn Telemetry real-time
@immutable
class RealtimeVitalEvent {
  const RealtimeVitalEvent({
    required this.patientId,
    required this.vital,
    this.isAlert = false,
    this.alertMessage,
    required this.timestamp,
  });

  final String patientId;
  final HealthVital vital;
  final bool isAlert;
  final String? alertMessage;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'isAlert': isAlert,
        'alertMessage': alertMessage,
        'timestamp': timestamp.toIso8601String(),
      };
}
