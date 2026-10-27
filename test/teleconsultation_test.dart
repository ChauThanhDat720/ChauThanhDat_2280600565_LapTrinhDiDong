import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_hospital/features/teleconsultation/domain/post_care_assistant.dart';
import 'package:smart_hospital/core/utils/app_timezone.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/teleconsultation/data/teleconsultation_repository.dart';
import 'package:smart_hospital/features/teleconsultation/domain/teleconsultation.dart';
import 'package:smart_hospital/features/teleconsultation/presentation/doctor_teleconsultations_screen.dart';
import 'package:smart_hospital/features/teleconsultation/presentation/post_care_chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppointmentStore.instance.clearForTest();
    TeleconsultationStore.instance.clearForTest();
  });

  group('Post-Care Teleconsultation Domain Tests', () {
    test('Calculates 7-day expiration and days remaining correctly', () {
      final now = AppTimezone.now();
      final activeSession = TeleconsultationSession(
        id: 'tc-test-1',
        appointmentId: 'apt-1',
        patientId: 'patient-1',
        patientName: 'Nguyễn Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Tim mạch',
        expiresAt: now.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );

      expect(activeSession.isExpired, isFalse);
      expect(activeSession.isClosed, isFalse);
      expect(activeSession.canChat, isTrue);
      expect(activeSession.daysRemaining, 7);
      expect(activeSession.remainingLabel, contains('Còn 7 ngày'));

      final expiredSession = activeSession.copyWith(
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      expect(expiredSession.isExpired, isTrue);
      expect(expiredSession.canChat, isFalse);
      expect(expiredSession.remainingLabel, 'Hết hạn theo dõi 7 ngày');

      final closedSession = activeSession.copyWith(
        status: TeleconsultationStatus.closed,
      );
      expect(closedSession.isClosed, isTrue);
      expect(closedSession.canChat, isFalse);
      expect(closedSession.remainingLabel, 'Đã kết thúc tư vấn');
    });

    test('Serializes to and from JSON preserving all fields', () {
      final now = AppTimezone.now();
      final message = TeleconsultationMessage(
        id: 'msg-100',
        sessionId: 'tc-100',
        senderType: MessageSenderType.patient,
        senderId: 'pat-1',
        senderName: 'Nguyễn Văn An',
        message: 'Em uống thuốc thấy hơi buồn nôn.',
        imageUrl: 'https://example.com/rash.jpg',
        isRead: false,
        createdAt: now,
      );

      final json = message.toJson();
      final revived = TeleconsultationMessage.fromJson(json);

      expect(revived.id, 'msg-100');
      expect(revived.isPatient, isTrue);
      expect(revived.message, 'Em uống thuốc thấy hơi buồn nôn.');
      expect(revived.imageUrl, 'https://example.com/rash.jpg');
    });
  });

  group('Teleconsultation Repository & Store Tests', () {
    test(
      'getOrCreateSession initializes session and system welcome message',
      () async {
        const repo = LocalTeleconsultationRepository();
        final session = await repo.getOrCreateSession('APT-999');

        expect(session.appointmentId, 'APT-999');
        expect(session.canChat, isTrue);
        expect(session.messages.length, greaterThanOrEqualTo(1));
        expect(session.messages.first.isSystem, isTrue);
        expect(session.messages.first.message, contains('Chào bạn!'));
      },
    );

    test('Patient sends message and doctor replies & closes session', () async {
      const repo = LocalTeleconsultationRepository();
      final session = await repo.getOrCreateSession('APT-CHAT-1');

      // Patient sends message
      final msg = await repo.sendMessage(
        session.id,
        senderType: MessageSenderType.patient,
        senderId: 'pat-1',
        senderName: 'Nguyễn Văn An',
        message: 'Bác sĩ cho em hỏi thuốc này uống trước ăn hay sau ăn ạ?',
      );
      expect(msg.isPatient, isTrue);

      final reloaded = TeleconsultationStore.instance.findById(session.id);
      expect(reloaded?.messages.length, 3);
      expect(reloaded?.messages.last.isAssistant, isTrue);
      expect(reloaded?.messages[1].message, contains('uống trước ăn'));

      // Doctor replies
      await repo.sendMessage(
        session.id,
        senderType: MessageSenderType.doctor,
        senderId: 'dr-linh',
        senderName: 'BS. Trần Thảo Linh',
        message: 'Thuốc này em nên uống sau khi ăn no 30 phút nhé.',
      );

      final afterReply = TeleconsultationStore.instance.findById(session.id);
      expect(afterReply?.messages.length, 4);

      // Doctor closes session
      final closed = await repo.closeSession(
        session.id,
        closedByName: 'BS. Trần Thảo Linh',
      );
      expect(closed.isClosed, isTrue);
      expect(closed.canChat, isFalse);

      // Subsequent messages rejected
      expect(
        () => repo.sendMessage(
          session.id,
          senderType: MessageSenderType.patient,
          senderId: 'pat-1',
          senderName: 'Nguyễn Văn An',
          message: 'Dạ vâng.',
        ),
        throwsStateError,
      );
    });
  });

  group('Post-care persistence and automation regressions', () {
    const repo = LocalTeleconsultationRepository();

    Future<void> ask(TeleconsultationSession session, String text) => repo
        .sendMessage(
          session.id,
          senderType: MessageSenderType.patient,
          senderId: session.patientId,
          senderName: session.patientName,
          message: text,
        )
        .then((_) {});

    test(
      'Chat, toggle, timestamps and closed status survive store restart',
      () async {
        final session = await repo.getOrCreateSession('persist-chat');
        await ask(session, 'Em quên uống thuốc');
        await repo.setAutoReplyEnabled(session.id, false);
        final before = TeleconsultationStore.instance.findById(session.id)!;
        TeleconsultationStore.instance.clearForTest();
        final restored = await repo.getOrCreateSession('persist-chat');
        expect(restored.messages.length, 3);
        expect(restored.messages.last.isAssistant, isTrue);
        expect(restored.autoReplyEnabled, isFalse);
        expect(restored.expiresAt, before.expiresAt);
        expect(
          restored.messages.first.createdAt,
          before.messages.first.createdAt,
        );
        expect(restored.lastMessageAt, before.lastMessageAt);
        expect(restored.lastMessageSender, before.lastMessageSender);
        await repo.closeSession(session.id);
        TeleconsultationStore.instance.clearForTest();
        expect(
          (await repo.getOrCreateSession('persist-chat')).isClosed,
          isTrue,
        );
      },
    );

    test(
      'Toggle off skips automatic replies; doctor messages never trigger a bot',
      () async {
        final session = await repo.getOrCreateSession('toggle-chat');
        await repo.setAutoReplyEnabled(session.id, false);
        await ask(session, 'Xin chào');
        await repo.sendMessage(
          session.id,
          senderType: MessageSenderType.doctor,
          senderId: session.doctorId,
          senderName: session.doctorName,
          message: 'Chào bạn',
        );
        expect(
          TeleconsultationStore.instance
              .findById(session.id)!
              .messages
              .where((m) => m.isAssistant),
          isEmpty,
        );
        await repo.setAutoReplyEnabled(session.id, true);
        await ask(session, 'Xin chào');
        expect(
          TeleconsultationStore.instance
              .findById(session.id)!
              .messages
              .where((m) => m.isAssistant),
          hasLength(1),
        );
      },
    );

    test('Concurrent messages persist; reading as patient keeps doctor unread count', () async {
      final session = await repo.getOrCreateSession('concurrent-chat');
      await Future.wait([ask(session, 'Một'), ask(session, 'Hai')]);
      await repo.markAsRead(session.id, MessageSenderType.patient);
      final saved = TeleconsultationStore.instance.findById(session.id)!;
      expect(saved.messages.where((m) => m.isPatient), hasLength(2));
      expect(saved.messages.where((m) => m.isAssistant), hasLength(2));
      expect(saved.unreadCount, 2);
      await repo.markAsRead(session.id, MessageSenderType.doctor);
      expect(
        TeleconsultationStore.instance.findById(session.id)!.unreadCount,
        0,
      );
    });

    test('Empty and expired messages are rejected', () async {
      final session = await repo.getOrCreateSession('expired-chat');
      await expectLater(ask(session, '  '), throwsArgumentError);
      await TeleconsultationStore.instance.saveSession(
        session.copyWith(
          expiresAt: AppTimezone.now().subtract(const Duration(days: 1)),
        ),
      );
      await expectLater(ask(session, 'Xin chào'), throwsStateError);
    });

    test(
      'Patient session filtering does not expose other demo patients',
      () async {
        final sessions = await repo.getPatientSessions('demo-patient');
        expect(sessions, isNotEmpty);
        expect(sessions.every((s) => s.patientId == 'demo-patient'), isTrue);
      },
    );

    test('Assistant prioritizes urgent symptoms, handles accents, and does not invent doses', () async {
      final session = await repo.getOrCreateSession('assistant-rules');
      const bot = PostCareAssistant();
      expect(
        bot.reply(session, 'Em quên thuốc và KHÓ THỞ, sưng môi'),
        contains('cấp cứu'),
      );
      expect(
        bot.reply(session, 'em quen uong thuoc'),
        contains('không tự uống gấp đôi'),
      );
      expect(
        bot.reply(
          session.copyWith(prescription: 'Đơn được bác sĩ lưu'),
          'Thuốc này uống trước hay sau ăn?',
        ),
        contains('Đơn được bác sĩ lưu'),
      );
      expect(
        bot.reply(session, 'Em gửi ảnh', hasImage: true),
        contains('không phân tích'),
      );
    });
  });

  group('Teleconsultation UI Widget Tests', () {
    testWidgets(
      'PostCareChatScreen renders medical summary, messages, and sends quick prompt',
      (tester) async {
        final now = AppTimezone.now();
        final testAppt = Appointment(
          id: 'APT-TEST-UI',
          patientId: 'demo-patient',
          patientName: 'Nguyễn Văn An',
          doctorId: 'dr-linh',
          doctorName: 'BS. Trần Thảo Linh',
          department: 'Khoa Tim mạch',
          specialty: 'Tim mạch can thiệp',
          date: now.subtract(const Duration(days: 1)),
          time: '08:30',
          reason: 'Huyết áp cao',
          status: AppointmentStatus.completed,
          diagnosis: 'Tăng huyết áp vô căn độ 1',
          prescription: 'Amlodipine 5mg x 1 viên/ngày',
          createdAt: now.subtract(const Duration(days: 1)),
        );
        AppointmentStore.instance.addAppointment(testAppt);

        await tester.pumpWidget(
          const MaterialApp(
            home: PostCareChatScreen(
              appointmentId: 'APT-TEST-UI',
              isDoctorView: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Doctor title and department in app bar
        expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);
        expect(find.text('Khoa Tim mạch'), findsOneWidget);

        // Verify Sticky Medical Summary Accordion
        expect(
          find.text('Tóm tắt Bệnh án & Đơn thuốc điều trị'),
          findsOneWidget,
        );
        expect(find.text('Tăng huyết áp vô căn độ 1'), findsOneWidget);
        expect(find.text('Amlodipine 5mg x 1 viên/ngày'), findsOneWidget);

        // Verify Quick prompts carousel
        expect(
          find.text('💊 Thuốc này uống trước hay sau bữa ăn ạ?'),
          findsOneWidget,
        );

        // Tap quick prompt to send message
        await tester.tap(
          find.text('💊 Thuốc này uống trước hay sau bữa ăn ạ?'),
        );
        await tester.pumpAndSettle();

        // Verify message is now displayed in chat bubble
        expect(
          find.text('💊 Thuốc này uống trước hay sau bữa ăn ạ?'),
          findsWidgets,
        );
        final saved = TeleconsultationStore.instance.findByAppointmentId(
          'APT-TEST-UI',
        )!;
        expect(saved.messages.last.isAssistant, isTrue);
        expect(saved.messages.last.message, contains('Amlodipine'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'DoctorTeleconsultationsScreen renders session list and filter chips',
      (tester) async {
        TeleconsultationStore.instance.seedIfEmpty();

        await tester.pumpWidget(
          const MaterialApp(
            home: DoctorTeleconsultationsScreen(
              doctorId: 'dr-linh',
              doctorName: 'BS. Trần Thảo Linh',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tư vấn Y tế Hậu khám (7 ngày)'), findsOneWidget);
        expect(find.textContaining('Tất cả'), findsOneWidget);
        expect(find.textContaining('Chờ phản hồi'), findsOneWidget);
        expect(find.textContaining('Đang mở'), findsOneWidget);

        // Verify patient card from seed
        expect(find.text('Lê Hoàng Nam'), findsOneWidget);
        expect(find.textContaining('Rối loạn nhịp tim nhẹ'), findsOneWidget);
        expect(find.text('Chạm để mở hội thoại ➔'), findsWidgets);
      },
    );
  });
}
