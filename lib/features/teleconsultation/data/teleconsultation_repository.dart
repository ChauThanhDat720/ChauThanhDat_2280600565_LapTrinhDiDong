import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/app_timezone.dart';
import '../../appointments/domain/appointment.dart';
import '../domain/teleconsultation.dart';

abstract interface class TeleconsultationRepository {
  Future<TeleconsultationSession> getOrCreateSession(String appointmentId);
  Future<List<TeleconsultationSession>> getDoctorSessions(String doctorId);
  Future<List<TeleconsultationSession>> getPatientSessions(String patientId);
  Future<TeleconsultationMessage> sendMessage(
    String sessionId, {
    required MessageSenderType senderType,
    required String senderId,
    required String senderName,
    required String message,
    String? imageUrl,
  });
  Future<void> markAsRead(String sessionId, MessageSenderType readerType);
  Future<TeleconsultationSession> closeSession(String sessionId, {String? closedByName});
}

class TeleconsultationStore extends ChangeNotifier {
  TeleconsultationStore._();
  static final instance = TeleconsultationStore._();

  final List<TeleconsultationSession> _sessions = [];
  List<TeleconsultationSession> get sessions => List.unmodifiable(_sessions);

  void clearForTest() {
    _sessions.clear();
    notifyListeners();
  }

  void seedIfEmpty() {
    if (_sessions.isNotEmpty) return;
    final now = AppTimezone.now();

    // Demo Session 1: Completed appointment APT-103 with BS. Tran Thao Linh
    final session1 = TeleconsultationSession(
      id: 'tc-apt-103',
      appointmentId: 'APT-103',
      patientId: 'BN-03',
      patientName: 'Lê Hoàng Nam',
      doctorId: 'dr-linh',
      doctorName: 'BS. Trần Thảo Linh',
      department: 'Tim mạch',
      diagnosis: 'Rối loạn nhịp tim nhẹ, stress kéo dài',
      prescription: '1. Concor 2.5mg - 1 viên/ngày buổi sáng\n2. Magne B6 - 2 viên/ngày chia 2 lần',
      status: TeleconsultationStatus.active,
      expiresAt: now.add(const Duration(days: 6)),
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(hours: 2)),
      unreadCount: 1,
      lastMessage: 'Dạ vâng, em cảm ơn bác sĩ nhiều ạ!',
      lastMessageSender: 'Lê Hoàng Nam',
      lastMessageAt: now.subtract(const Duration(hours: 2)),
      messages: [
        TeleconsultationMessage(
          id: 'msg-seed-1',
          sessionId: 'tc-apt-103',
          senderType: MessageSenderType.system,
          senderId: 'system',
          senderName: 'Hệ thống Bệnh viện',
          message: 'Chào bạn! Kênh tư vấn y tế hậu khám 7 ngày với BS. Trần Thảo Linh đã được kích hoạt. Bạn có thể gửi câu hỏi về phản ứng thuốc, thắc mắc liều dùng hoặc gửi hình ảnh triệu chứng tại đây.',
          isRead: true,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        TeleconsultationMessage(
          id: 'msg-seed-2',
          sessionId: 'tc-apt-103',
          senderType: MessageSenderType.patient,
          senderId: 'BN-03',
          senderName: 'Lê Hoàng Nam',
          message: 'Thưa bác sĩ, sáng nay em uống Concor 2.5mg xong cảm giác hơi choáng váng nhẹ khi đứng dậy nhanh, có sao không ạ?',
          isRead: true,
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
        TeleconsultationMessage(
          id: 'msg-seed-3',
          sessionId: 'tc-apt-103',
          senderType: MessageSenderType.doctor,
          senderId: 'dr-linh',
          senderName: 'BS. Trần Thảo Linh',
          message: 'Chào Nam, đây là phản ứng thông thường khi bắt đầu làm quen với thuốc chẹn beta. Em chú ý đứng dậy từ từ, uống đủ nước. Nếu tình trạng choáng váng kéo dài trên 3 ngày thì báo lại bác sĩ nhé.',
          isRead: true,
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        TeleconsultationMessage(
          id: 'msg-seed-4',
          sessionId: 'tc-apt-103',
          senderType: MessageSenderType.patient,
          senderId: 'BN-03',
          senderName: 'Lê Hoàng Nam',
          message: 'Dạ vâng, em cảm ơn bác sĩ nhiều ạ!',
          isRead: false,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ],
    );

    // Demo Session 2: Patient BN-01 (Demo Patient) with BS. Tran Thao Linh
    final session2 = TeleconsultationSession(
      id: 'tc-apt-demo-patient',
      appointmentId: 'APT-001',
      patientId: 'demo-patient',
      patientName: 'Nguyễn Văn An',
      doctorId: 'dr-linh',
      doctorName: 'BS. Trần Thảo Linh',
      department: 'Tim mạch',
      diagnosis: 'Tăng huyết áp nguyên phát độ 1',
      prescription: 'Amlodipine 5mg x 1 viên/ngày uống sau ăn sáng',
      status: TeleconsultationStatus.active,
      expiresAt: now.add(const Duration(days: 5)),
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 1)),
      unreadCount: 0,
      lastMessage: 'BS. Trần Thảo Linh: Thuốc uống sau ăn sáng bạn nhé.',
      lastMessageSender: 'BS. Trần Thảo Linh',
      lastMessageAt: now.subtract(const Duration(hours: 1)),
      messages: [
        TeleconsultationMessage(
          id: 'msg-seed-p1',
          sessionId: 'tc-apt-demo-patient',
          senderType: MessageSenderType.system,
          senderId: 'system',
          senderName: 'Hệ thống Bệnh viện',
          message: 'Chào bạn! Kênh tư vấn y tế hậu khám 7 ngày với BS. Trần Thảo Linh đã được kích hoạt. Bạn có thể gửi câu hỏi và hình ảnh triệu chứng tại đây.',
          isRead: true,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        TeleconsultationMessage(
          id: 'msg-seed-p2',
          sessionId: 'tc-apt-demo-patient',
          senderType: MessageSenderType.doctor,
          senderId: 'dr-linh',
          senderName: 'BS. Trần Thảo Linh',
          message: 'Chào anh An, anh nhớ theo dõi huyết áp sáng tối và ghi lại vào sổ theo dõi nhé. Cần hỗ trợ gì cứ nhắn bác sĩ.',
          isRead: true,
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );

    _sessions.add(session1);
    _sessions.add(session2);
    notifyListeners();
  }

  void addSession(TeleconsultationSession session) {
    _sessions.removeWhere((s) => s.id == session.id || s.appointmentId == session.appointmentId);
    _sessions.insert(0, session);
    notifyListeners();
  }

  void replaceSession(TeleconsultationSession session) {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.insert(0, session);
    }
    notifyListeners();
  }

  TeleconsultationSession? findById(String id) {
    return _sessions.cast<TeleconsultationSession?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
  }

  TeleconsultationSession? findByAppointmentId(String appointmentId) {
    return _sessions.cast<TeleconsultationSession?>().firstWhere(
          (s) => s?.appointmentId == appointmentId,
          orElse: () => null,
        );
  }
}

class LocalTeleconsultationRepository implements TeleconsultationRepository {
  const LocalTeleconsultationRepository();

  @override
  Future<TeleconsultationSession> getOrCreateSession(String appointmentId) async {
    TeleconsultationStore.instance.seedIfEmpty();
    var session = TeleconsultationStore.instance.findByAppointmentId(appointmentId);

    if (session == null) {
      // Find appointment in AppointmentStore
      final appts = AppointmentStore.instance.appointments;
      final appt = appts.cast<Appointment?>().firstWhere(
            (a) => a?.id == appointmentId,
            orElse: () => null,
          );

      final now = AppTimezone.now();
      final expiresAt = now.add(const Duration(days: 7));
      final sessionId = 'tc-$appointmentId';

      final doctorName = appt?.doctorName ?? 'BS. Trần Thảo Linh';
      final patientName = appt?.patientName ?? 'Bệnh nhân';
      final diagnosis = appt?.diagnosis ?? 'Theo dõi sau khám';
      final prescription = appt?.prescription ?? '';
      final department = appt?.department ?? 'Khoa Tim mạch';
      final doctorId = appt?.doctorId ?? 'dr-linh';
      final patientId = appt?.patientId ?? 'demo-patient';

      final welcomeMsg = TeleconsultationMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        sessionId: sessionId,
        senderType: MessageSenderType.system,
        senderId: 'system',
        senderName: 'Hệ thống Bệnh viện',
        message: 'Chào bạn! Kênh tư vấn y tế hậu khám 7 ngày với $doctorName đã được kích hoạt. Bạn có thể gửi câu hỏi về phản ứng thuốc, liều dùng hoặc hình ảnh triệu chứng tại đây.',
        isRead: true,
        createdAt: now,
      );

      session = TeleconsultationSession(
        id: sessionId,
        appointmentId: appointmentId,
        patientId: patientId,
        patientName: patientName,
        doctorId: doctorId,
        doctorName: doctorName,
        department: department,
        diagnosis: diagnosis,
        prescription: prescription,
        status: TeleconsultationStatus.active,
        expiresAt: expiresAt,
        createdAt: now,
        updatedAt: now,
        messages: [welcomeMsg],
        unreadCount: 0,
      );

      TeleconsultationStore.instance.addSession(session);
    }

    return session;
  }

  @override
  Future<List<TeleconsultationSession>> getDoctorSessions(String doctorId) async {
    TeleconsultationStore.instance.seedIfEmpty();
    final all = TeleconsultationStore.instance.sessions;
    if (doctorId == 'all') return all;
    return all.where((s) => s.doctorId == doctorId).toList();
  }

  @override
  Future<List<TeleconsultationSession>> getPatientSessions(String patientId) async {
    TeleconsultationStore.instance.seedIfEmpty();
    final all = TeleconsultationStore.instance.sessions;
    return all.where((s) => s.patientId == patientId || patientId == 'demo-patient').toList();
  }

  @override
  Future<TeleconsultationMessage> sendMessage(
    String sessionId, {
    required MessageSenderType senderType,
    required String senderId,
    required String senderName,
    required String message,
    String? imageUrl,
  }) async {
    TeleconsultationStore.instance.seedIfEmpty();
    final session = TeleconsultationStore.instance.findById(sessionId);
    if (session == null) {
      throw StateError('Không tìm thấy phiên tư vấn.');
    }
    if (!session.canChat) {
      throw StateError('Phiên tư vấn hậu khám này đã kết thúc.');
    }

    final now = AppTimezone.now();
    final newMsg = TeleconsultationMessage(
      id: 'msg-${now.millisecondsSinceEpoch}',
      sessionId: sessionId,
      senderType: senderType,
      senderId: senderId,
      senderName: senderName,
      message: message.trim(),
      imageUrl: imageUrl,
      isRead: false,
      createdAt: now,
    );

    final updatedMessages = [...session.messages, newMsg];
    final isDoctor = senderType == MessageSenderType.doctor;
    final unread = isDoctor ? 0 : session.unreadCount + 1;

    final updatedSession = session.copyWith(
      messages: updatedMessages,
      lastMessage: message.trim(),
      lastMessageSender: senderName,
      lastMessageAt: now,
      updatedAt: now,
      unreadCount: unread,
    );

    TeleconsultationStore.instance.replaceSession(updatedSession);
    return newMsg;
  }

  @override
  Future<void> markAsRead(String sessionId, MessageSenderType readerType) async {
    final session = TeleconsultationStore.instance.findById(sessionId);
    if (session == null) return;

    final updatedMessages = session.messages.map((m) {
      if ((readerType == MessageSenderType.doctor && m.isPatient) ||
          (readerType == MessageSenderType.patient && m.isDoctor)) {
        return TeleconsultationMessage(
          id: m.id,
          sessionId: m.sessionId,
          senderType: m.senderType,
          senderId: m.senderId,
          senderName: m.senderName,
          message: m.message,
          imageUrl: m.imageUrl,
          isRead: true,
          createdAt: m.createdAt,
        );
      }
      return m;
    }).toList();

    final updatedSession = session.copyWith(
      messages: updatedMessages,
      unreadCount: 0,
    );
    TeleconsultationStore.instance.replaceSession(updatedSession);
  }

  @override
  Future<TeleconsultationSession> closeSession(String sessionId, {String? closedByName}) async {
    final session = TeleconsultationStore.instance.findById(sessionId);
    if (session == null) {
      throw StateError('Không tìm thấy phiên tư vấn.');
    }

    final now = AppTimezone.now();
    final closeMsg = TeleconsultationMessage(
      id: 'msg-${now.millisecondsSinceEpoch}',
      sessionId: sessionId,
      senderType: MessageSenderType.system,
      senderId: 'system',
      senderName: 'Hệ thống Bệnh viện',
      message: '${closedByName ?? session.doctorName} đã đóng phiên tư vấn này. Chúc bạn sức khỏe mau bình phục!',
      isRead: true,
      createdAt: now,
    );

    final updated = session.copyWith(
      status: TeleconsultationStatus.closed,
      messages: [...session.messages, closeMsg],
      updatedAt: now,
    );

    TeleconsultationStore.instance.replaceSession(updated);
    return updated;
  }
}

class RemoteTeleconsultationRepository implements TeleconsultationRepository {
  const RemoteTeleconsultationRepository(this._client);
  final ApiClient _client;

  @override
  Future<TeleconsultationSession> getOrCreateSession(String appointmentId) async {
    final res = await _client.get('/teleconsultations/appointment/$appointmentId');
    return TeleconsultationSession.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<List<TeleconsultationSession>> getDoctorSessions(String doctorId) async {
    final res = await _client.get('/teleconsultations/doctor/$doctorId');
    final items = res is Map<String, dynamic> ? res['items'] : res;
    return (items as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TeleconsultationSession.fromJson)
        .toList();
  }

  @override
  Future<List<TeleconsultationSession>> getPatientSessions(String patientId) async {
    final res = await _client.get('/teleconsultations/patient/$patientId');
    final items = res is Map<String, dynamic> ? res['items'] : res;
    return (items as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TeleconsultationSession.fromJson)
        .toList();
  }

  @override
  Future<TeleconsultationMessage> sendMessage(
    String sessionId, {
    required MessageSenderType senderType,
    required String senderId,
    required String senderName,
    required String message,
    String? imageUrl,
  }) async {
    final res = await _client.post(
      '/teleconsultations/sessions/$sessionId/messages',
      body: {
        'senderType': senderType.name,
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'imageUrl': imageUrl,
      },
    );
    return TeleconsultationMessage.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<void> markAsRead(String sessionId, MessageSenderType readerType) async {
    await _client.post(
      '/teleconsultations/sessions/$sessionId/read',
      body: {'readerType': readerType.name},
    );
  }

  @override
  Future<TeleconsultationSession> closeSession(String sessionId, {String? closedByName}) async {
    final res = await _client.patch(
      '/teleconsultations/sessions/$sessionId/close',
      body: {'closedByName': closedByName},
    );
    return TeleconsultationSession.fromJson(res as Map<String, dynamic>);
  }
}
