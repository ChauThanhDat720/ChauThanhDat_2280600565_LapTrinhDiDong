import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_hospital/features/family/data/family_repository.dart';
import 'package:smart_hospital/features/family/domain/family_member.dart';
import 'package:smart_hospital/features/family/presentation/family_members_screen.dart';
import 'package:smart_hospital/features/family/presentation/family_selector_bar.dart';
import 'package:smart_hospital/features/family/presentation/family_profile_manager.dart';
import 'package:smart_hospital/features/teleconsultation/data/teleconsultation_repository.dart';
import 'package:smart_hospital/features/teleconsultation/domain/teleconsultation.dart';
import 'package:smart_hospital/features/teleconsultation/presentation/post_care_chat_screen.dart';

class _FailedSaveRepository extends LocalFamilyRepository {
  @override
  Future<FamilyMember> updateMember(FamilyMember member) async =>
      throw StateError('Lưu thất bại');
}

class _DelayedSendRepository extends LocalTeleconsultationRepository {
  final pending = Completer<TeleconsultationMessage>();
  int calls = 0;

  @override
  Future<TeleconsultationMessage> sendMessage(
    String sessionId, {
    required MessageSenderType senderType,
    required String senderId,
    required String senderName,
    required String message,
    String? imageUrl,
  }) {
    calls++;
    return pending.future;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TeleconsultationStore.instance.clearForTest();
    FamilyProfileManager.instance.updateMemberList([]);
  });

  testWidgets(
    'Failed save keeps the family editor open and does not change stored data',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: FamilyMembersScreen(repository: _FailedSaveRepository()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chỉnh sửa').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Chưa lưu');
      await tester.ensureVisible(find.text('Cập nhật hồ sơ'));
      await tester.tap(find.text('Cập nhật hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
      expect(find.text('Chưa lưu'), findsOneWidget);
      expect(
        (await LocalFamilyRepository().getMembers()).first.fullName,
        'Nguyễn Văn An',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Double send is blocked and a failed message keeps its draft', (
    tester,
  ) async {
    final repository = _DelayedSendRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PostCareChatScreen(
          appointmentId: 'failed-send',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nội dung cần giữ lại');
    await tester.tap(find.byTooltip('Gửi tin nhắn'));
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi tin nhắn'));
    await tester.pump();
    expect(repository.calls, 1);
    repository.pending.completeError(StateError('Không thể gửi'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung cần giữ lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long active family name fits a phone header', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LocalFamilyRepository();
    final member = (await repo.getMembers()).first;
    await repo.updateMember(
      member.copyWith(
        fullName: 'Nguyễn Thị Ngọc Ánh tên thành viên gia đình rất dài',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FamilySelectorBar(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chat controls remain usable at phone size with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      const MaterialApp(home: PostCareChatScreen(appointmentId: 'phone-chat')),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Xin chào');
    await tester.tap(find.byTooltip('Gửi tin nhắn'));
    await tester.pumpAndSettle();
    expect(
      TeleconsultationStore.instance
          .findByAppointmentId('phone-chat')!
          .messages
          .last
          .isAssistant,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
