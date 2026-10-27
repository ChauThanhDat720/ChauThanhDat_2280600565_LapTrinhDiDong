import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_json_storage.dart';
import '../domain/post_care_assistant.dart';
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
  Future<TeleconsultationSession> setAutoReplyEnabled(
    String sessionId,
    bool enabled,
  );
  Future<TeleconsultationSession> closeSession(
    String sessionId, {
    String? closedByName,
  });
}

class TeleconsultationStore extends ChangeNotifier {
  TeleconsultationStore._();
  static final instance = TeleconsultationStore._();

  final List<TeleconsultationSession> _sessions = [];
  static const _storageKey = 'post_care_sessions_v1';
  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _restore();

  Future<void> _restore() async {
    try {
      final saved = await LocalJsonStorage.read(_storageKey);
      if (saved != null) {
        _sessions
          ..clear()
          ..addAll(saved.map(TeleconsultationSession.fromJson));
      } else {
        seedIfEmpty();
        await LocalJsonStorage.write(
          _storageKey,
          _sessions.map((s) => s.toJson()).toList(),
        );
      }
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<void> _commit(List<TeleconsultationSession> sessions) async {
    await LocalJsonStorage.write(
      _storageKey,
      sessions.map((s) => s.toJson()).toList(),
    );
    _sessions
      ..clear()
      ..addAll(sessions);
    notifyListeners();
  }

  Future<void> saveSession(TeleconsultationSession session) =>
      LocalJsonStorage.exclusive(_storageKey, () async {
        await ensureLoaded();
        await _commit([
          session,
          ..._sessions.where(
            (s) =>
                s.id != session.id && s.appointmentId != session.appointmentId,
          ),
        ]);
      });

  Future<TeleconsultationSession> updateSession(
    String id,
    TeleconsultationSession Function(TeleconsultationSession) update,
  ) => LocalJsonStorage.exclusive(_storageKey, () async {
    await ensureLoaded();
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index < 0) throw StateError('Không tìm thấy phiên tư vấn.');
    final changed = update(_sessions[index]);
    final next = List<TeleconsultationSession>.of(_sessions);
    next[index] = changed;
    await _commit(next);
    return changed;
  });
  List<TeleconsultationSession> get sessions => List.unmodifiable(_sessions);

  void clearForTest() {
    _sessions.clear();
    _loading = null;
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
  Future<TeleconsultationSession> getOrCreateSession(
    String appointmentId,
  ) async {
    await TeleconsultationStore.instance.ensureLoaded();
    var session = TeleconsultationStore.instance.findByAppointmentId(
      appointmentId,
    );

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
        message:
            'Chào bạn! Kênh tư vấn y tế hậu khám 7 ngày với $doctorName đã được kích hoạt. Bạn có thể gửi câu hỏi về phản ứng thuốc, liều dùng hoặc hình ảnh triệu chứng tại đây.',
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

      await TeleconsultationStore.instance.saveSession(session);
    }

    return session;
  }

  @override
  Future<List<TeleconsultationSession>> getDoctorSessions(
    String doctorId,
  ) async {
    await TeleconsultationStore.instance.ensureLoaded();
    final all = TeleconsultationStore.instance.sessions;
    if (doctorId == 'all') return all;
    return all.where((s) => s.doctorId == doctorId).toList();
  }

  @override
  Future<List<TeleconsultationSession>> getPatientSessions(
    String patientId,
  ) async {
    await TeleconsultationStore.instance.ensureLoaded();
    final all = TeleconsultationStore.instance.sessions;
    return all.where((s) => s.patientId == patientId).toList();
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
    if (message.trim().isEmpty && imageUrl == null) {
      throw ArgumentError('Vui lòng nhập nội dung hoặc chọn ảnh.');
    }
    late TeleconsultationMessage sent;
    await TeleconsultationStore.instance.updateSession(sessionId, (session) {
      if (!session.canChat) {
        throw StateError('Phiên tư vấn hậu khám này đã kết thúc.');
      }
      final now = AppTimezone.now();
      final id = DateTime.now().microsecondsSinceEpoch;
      sent = TeleconsultationMessage(
        id: 'msg-$id',
        sessionId: sessionId,
        senderType: senderType,
        senderId: senderId,
        senderName: senderName,
        message: message.trim(),
        imageUrl: imageUrl,
        createdAt: now,
      );
      final messages = [...session.messages, sent];
      if (senderType == MessageSenderType.patient && session.autoReplyEnabled) {
        messages.add(
          TeleconsultationMessage(
            id: 'assistant-$id',
            sessionId: sessionId,
            senderType: MessageSenderType.assistant,
            senderId: 'post-care-assistant',
            senderName: 'Trợ lý hậu khám tự động',
            message: const PostCareAssistant().reply(
              session,
              message,
              hasImage: imageUrl != null,
            ),
            createdAt: now,
            isRead: false,
          ),
        );
      }
      final last = messages.last;
      return session.copyWith(
        messages: messages,
        lastMessage: last.message,
        lastMessageSender: last.senderName,
        lastMessageAt: now,
        updatedAt: now,
        unreadCount: senderType == MessageSenderType.patient
            ? session.unreadCount + 1
            : senderType == MessageSenderType.doctor
            ? 0
            : session.unreadCount,
      );
    });
    return sent;
  }

  @override
  Future<void> markAsRead(
    String sessionId,
    MessageSenderType readerType,
  ) async {
    await TeleconsultationStore.instance.updateSession(sessionId, (session) {
      final messages = session.messages.map((m) {
        final shouldRead = readerType == MessageSenderType.doctor
            ? m.isPatient
            : readerType == MessageSenderType.patient &&
                  (m.isDoctor || m.isAssistant);
        if (!shouldRead || m.isRead) return m;
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
      }).toList();
      return session.copyWith(
        messages: messages,
        unreadCount: readerType == MessageSenderType.doctor
            ? 0
            : session.unreadCount,
      );
    });
  }

  @override
  Future<TeleconsultationSession> setAutoReplyEnabled(
    String sessionId,
    bool enabled,
  ) => TeleconsultationStore.instance.updateSession(sessionId, (session) {
    if (!session.canChat) throw StateError('Phiên tư vấn đã kết thúc.');
    return session.copyWith(
      autoReplyEnabled: enabled,
      updatedAt: AppTimezone.now(),
    );
  });

  @override
  Future<TeleconsultationSession> closeSession(
    String sessionId, {
    String? closedByName,
  }) => TeleconsultationStore.instance.updateSession(sessionId, (session) {
    if (session.isClosed) return session;
    final now = AppTimezone.now();
    final message = TeleconsultationMessage(
      id: 'close-${DateTime.now().microsecondsSinceEpoch}',
      sessionId: sessionId,
      senderType: MessageSenderType.system,
      senderId: 'system',
      senderName: 'Hệ thống Bệnh viện',
      message:
          '${closedByName ?? session.doctorName} đã đóng phiên tư vấn này.',
      isRead: true,
      createdAt: now,
    );
    return session.copyWith(
      status: TeleconsultationStatus.closed,
      messages: [...session.messages, message],
      updatedAt: now,
      lastMessage: message.message,
      lastMessageSender: message.senderName,
      lastMessageAt: now,
    );
  });
}

class RemoteTeleconsultationRepository implements TeleconsultationRepository {
  const RemoteTeleconsultationRepository(this._client);
  final ApiClient _client;

  @override
  Future<TeleconsultationSession> getOrCreateSession(
    String appointmentId,
  ) async {
    final res = await _client.get(
      '/teleconsultations/appointment/$appointmentId',
    );
    return TeleconsultationSession.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<List<TeleconsultationSession>> getDoctorSessions(
    String doctorId,
  ) async {
    final res = await _client.get('/teleconsultations/doctor/me');
    final items = res is Map<String, dynamic> ? res['items'] : res;
    return (items as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TeleconsultationSession.fromJson)
        .toList();
  }

  @override
  Future<List<TeleconsultationSession>> getPatientSessions(
    String patientId,
  ) async {
    final res = await _client.get('/teleconsultations/patient/me');
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
    String? imageKey;
    if (imageUrl != null) {
      if (!imageUrl.startsWith('data:')) {
        throw ArgumentError('Vui lòng chọn lại ảnh từ thiết bị.');
      }
      final data = Uri.parse(imageUrl).data!;
      final bytes = data.contentAsBytes();
      final attachment = await _client.post(
        '/teleconsultations/sessions/$sessionId/attachments',
        body: {'contentType': data.mimeType, 'size': bytes.length},
      ) as Map<String, dynamic>;
      await _client.uploadSigned(
        attachment['uploadUrl'] as String,
        bytes,
        Map<String, String>.from(attachment['headers'] as Map),
      );
      imageKey = attachment['objectKey'] as String;
    }
    final res = await _client.post(
      '/teleconsultations/sessions/$sessionId/messages',
      body: {
        'senderType': senderType.name,
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'imageKey': ?imageKey,
      },
    );
    return TeleconsultationMessage.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<TeleconsultationSession> setAutoReplyEnabled(
    String sessionId,
    bool enabled,
  ) async {
    final result = await _client.patch(
      '/teleconsultations/sessions/$sessionId',
      body: {'auto_reply_enabled': enabled},
    );
    return TeleconsultationSession.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<void> markAsRead(
    String sessionId,
    MessageSenderType readerType,
  ) async {
    await _client.post(
      '/teleconsultations/sessions/$sessionId/read',
      body: {'readerType': readerType.name},
    );
  }

  @override
  Future<TeleconsultationSession> closeSession(
    String sessionId, {
    String? closedByName,
  }) async {
    final res = await _client.patch(
      '/teleconsultations/sessions/$sessionId/close',
      body: {'closedByName': closedByName},
    );
    return TeleconsultationSession.fromJson(res as Map<String, dynamic>);
  }
}
