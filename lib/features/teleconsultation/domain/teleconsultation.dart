import '../../../core/utils/app_timezone.dart';

enum TeleconsultationStatus { active, closed, expired }

enum MessageSenderType { patient, doctor, system, assistant }

class TeleconsultationMessage {
  const TeleconsultationMessage({
    required this.id,
    required this.sessionId,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.imageUrl,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final MessageSenderType senderType;
  final String senderId;
  final String senderName;
  final String message;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  bool get isPatient => senderType == MessageSenderType.patient;
  bool get isDoctor => senderType == MessageSenderType.doctor;
  bool get isAssistant => senderType == MessageSenderType.assistant;
  bool get isSystem => senderType == MessageSenderType.system;

  String get formattedTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  factory TeleconsultationMessage.fromJson(Map<String, dynamic> json) {
    MessageSenderType type;
    final rawType = (json['sender_type'] ?? json['senderType'] ?? 'patient')
        .toString();
    if (rawType == 'assistant') {
      type = MessageSenderType.assistant;
    } else if (rawType == 'doctor') {
      type = MessageSenderType.doctor;
    } else if (rawType == 'system') {
      type = MessageSenderType.system;
    } else {
      type = MessageSenderType.patient;
    }

    return TeleconsultationMessage(
      id: json['id'] as String,
      sessionId: (json['session_id'] ?? json['sessionId']) as String,
      senderType: type,
      senderId: (json['sender_id'] ?? json['senderId'] ?? '') as String,
      senderName: (json['sender_name'] ?? json['senderName'] ?? '') as String,
      message: (json['message'] ?? '') as String,
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      isRead:
          json['is_read'] == true ||
          json['is_read'] == 1 ||
          json['isRead'] == true,
      createdAt: json['created_at'] != null
          ? AppTimezone.fromUtc(DateTime.parse(json['created_at'] as String))
          : AppTimezone.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'sender_type': senderType.name,
    'sender_id': senderId,
    'sender_name': senderName,
    'message': message,
    'image_url': imageUrl,
    'is_read': isRead,
    'created_at': AppTimezone.toUtc(createdAt).toIso8601String(),
  };
}

class TeleconsultationSession {
  const TeleconsultationSession({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.department,
    this.diagnosis,
    this.prescription,
    this.status = TeleconsultationStatus.active,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageAt,
    this.autoReplyEnabled = true,
  });

  final String id;
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String department;
  final String? diagnosis;
  final String? prescription;
  final TeleconsultationStatus status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TeleconsultationMessage> messages;
  final int unreadCount;
  final String? lastMessage;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final bool autoReplyEnabled;

  bool get isExpired =>
      status == TeleconsultationStatus.expired ||
      AppTimezone.now().isAfter(expiresAt);

  bool get isClosed => status == TeleconsultationStatus.closed;

  bool get canChat => !isExpired && !isClosed;

  int get daysRemaining {
    final now = AppTimezone.now();
    final diff = expiresAt.difference(now);
    if (diff.isNegative) return 0;
    return (diff.inMilliseconds / Duration.millisecondsPerDay).ceil();
  }

  String get remainingLabel {
    if (isClosed) return 'Đã kết thúc tư vấn';
    if (isExpired) return 'Hết hạn theo dõi 7 ngày';
    final days = daysRemaining;
    if (days <= 0) return 'Hết hạn hôm nay';
    return 'Còn $days ngày theo dõi';
  }

  TeleconsultationSession copyWith({
    String? id,
    String? appointmentId,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    String? department,
    String? diagnosis,
    String? prescription,
    TeleconsultationStatus? status,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TeleconsultationMessage>? messages,
    int? unreadCount,
    String? lastMessage,
    String? lastMessageSender,
    DateTime? lastMessageAt,
    bool? autoReplyEnabled,
  }) {
    return TeleconsultationSession(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      department: department ?? this.department,
      diagnosis: diagnosis ?? this.diagnosis,
      prescription: prescription ?? this.prescription,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      autoReplyEnabled: autoReplyEnabled ?? this.autoReplyEnabled,
    );
  }

  factory TeleconsultationSession.fromJson(Map<String, dynamic> json) {
    TeleconsultationStatus parsedStatus;
    final rawStatus = (json['status'] ?? 'active').toString();
    if (rawStatus == 'closed') {
      parsedStatus = TeleconsultationStatus.closed;
    } else if (rawStatus == 'expired') {
      parsedStatus = TeleconsultationStatus.expired;
    } else {
      parsedStatus = TeleconsultationStatus.active;
    }

    final rawMessages = json['messages'] as List? ?? const [];
    final messageList = rawMessages
        .whereType<Map<String, dynamic>>()
        .map(TeleconsultationMessage.fromJson)
        .toList();

    return TeleconsultationSession(
      id: json['id'] as String,
      appointmentId:
          (json['appointment_id'] ?? json['appointmentId']) as String,
      patientId: (json['patient_id'] ?? json['patientId']) as String,
      patientName:
          (json['patient_name'] ?? json['patientName'] ?? '') as String,
      doctorId: (json['doctor_id'] ?? json['doctorId']) as String,
      doctorName: (json['doctor_name'] ?? json['doctorName'] ?? '') as String,
      department: (json['department'] ?? '') as String,
      diagnosis: json['diagnosis'] as String?,
      prescription: json['prescription'] as String?,
      status: parsedStatus,
      expiresAt: json['expires_at'] != null
          ? AppTimezone.fromUtc(DateTime.parse(json['expires_at'] as String))
          : AppTimezone.now().add(const Duration(days: 7)),
      createdAt: json['created_at'] != null
          ? AppTimezone.fromUtc(DateTime.parse(json['created_at'] as String))
          : AppTimezone.now(),
      updatedAt: json['updated_at'] != null
          ? AppTimezone.fromUtc(DateTime.parse(json['updated_at'] as String))
          : AppTimezone.now(),
      messages: messageList,
      unreadCount: (json['unreadCount'] ?? json['unread_count'] ?? 0) as int,
      lastMessage: (json['lastMessage'] ?? json['last_message']) as String?,
      lastMessageSender:
          (json['lastMessageSender'] ?? json['last_message_sender']) as String?,
      lastMessageAt: (json['lastMessageAt'] ?? json['last_message_at']) != null
          ? AppTimezone.fromUtc(
              DateTime.parse(
                (json['lastMessageAt'] ?? json['last_message_at']) as String,
              ),
            )
          : null,
      autoReplyEnabled: json['auto_reply_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'appointment_id': appointmentId,
    'patient_id': patientId,
    'patient_name': patientName,
    'doctor_id': doctorId,
    'doctor_name': doctorName,
    'department': department,
    'diagnosis': diagnosis,
    'prescription': prescription,
    'status': status.name,
    'expires_at': AppTimezone.toUtc(expiresAt).toIso8601String(),
    'created_at': AppTimezone.toUtc(createdAt).toIso8601String(),
    'updated_at': AppTimezone.toUtc(updatedAt).toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
    'unreadCount': unreadCount,
    'lastMessage': lastMessage,
    'lastMessageSender': lastMessageSender,
    'lastMessageAt': lastMessageAt == null
        ? null
        : AppTimezone.toUtc(lastMessageAt!).toIso8601String(),
    'auto_reply_enabled': autoReplyEnabled,
  };
}
