import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_hospital/features/family/data/family_repository.dart';
import 'package:smart_hospital/features/family/domain/family_member.dart';
import 'package:smart_hospital/features/family/presentation/family_members_screen.dart';
import 'package:smart_hospital/features/family/presentation/family_profile_manager.dart';
import 'package:smart_hospital/features/family/presentation/family_selector_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FamilyProfileManager.instance.updateMemberList([]);
  });
  group('Family Member Domain Tests', () {
    test('Calculates age correctly from dateOfBirth', () {
      final dob = DateTime.now().subtract(const Duration(days: 365 * 30 + 10));
      final member = FamilyMember(
        id: 'mem-1',
        primaryPatientId: 'pt-1',
        fullName: 'Nguyễn Văn Test',
        relationship: FamilyRelationship.self,
        dateOfBirth: dob,
      );

      expect(member.age, greaterThanOrEqualTo(29));
      expect(member.formattedAge, contains('tuổi'));
      expect(member.isSelf, isTrue);
    });

    test('Serializes to and from JSON', () {
      final member = FamilyMember(
        id: 'mem-mother',
        primaryPatientId: 'pt-1',
        fullName: 'Trần Thị Mai',
        relationship: FamilyRelationship.mother,
        dateOfBirth: DateTime(1965, 8, 15),
        gender: 'Nữ',
        bhytCode: 'GD4798765432100',
        bloodType: 'A+',
        medicalHistory: 'Tăng huyết áp',
        isDefault: false,
      );

      final json = member.toJson();
      expect(json['full_name'], 'Trần Thị Mai');
      expect(json['relationship'], 'mother');
      expect(json['bhyt_code'], 'GD4798765432100');

      final fromJson = FamilyMember.fromJson(json);
      expect(fromJson.fullName, 'Trần Thị Mai');
      expect(fromJson.relationship, FamilyRelationship.mother);
      expect(fromJson.isSelf, isFalse);
    });
  });

  group('Family Repository Tests', () {
    late LocalFamilyRepository repository;

    setUp(() {
      repository = LocalFamilyRepository();
    });

    test('getMembers returns default seeded family members', () async {
      final members = await repository.getMembers();
      expect(members.length, greaterThanOrEqualTo(3));

      final self = members.firstWhere(
        (m) => m.relationship == FamilyRelationship.self,
      );
      final mother = members.firstWhere(
        (m) => m.relationship == FamilyRelationship.mother,
      );

      expect(self.fullName, 'Nguyễn Văn An');
      expect(self.isDefault, isTrue);
      expect(mother.fullName, 'Trần Thị Mai');
    });

    test('createMember adds new member and persists', () async {
      final newMember = FamilyMember(
        id: 'mem-father',
        primaryPatientId: 'pt-1',
        fullName: 'Nguyễn Văn Ba',
        relationship: FamilyRelationship.father,
        dateOfBirth: DateTime(1960, 5, 20),
        bhytCode: 'HT2791122334455',
      );

      final created = await repository.createMember(newMember);
      expect(created.id, 'mem-father');
      expect(created.fullName, 'Nguyễn Văn Ba');

      final all = await repository.getMembers();
      expect(all.any((m) => m.id == 'mem-father'), isTrue);
    });

    test('deleteMember prevents deleting self profile', () async {
      final members = await repository.getMembers();
      final self = members.firstWhere(
        (m) => m.relationship == FamilyRelationship.self,
      );

      expect(
        () async => await repository.deleteMember(self.id),
        throwsA(isA<Exception>()),
      );
    });

    test('setDefaultMember updates default flag across members', () async {
      final members = await repository.getMembers();
      final mother = members.firstWhere(
        (m) => m.relationship == FamilyRelationship.mother,
      );

      final updated = await repository.setDefaultMember(mother.id);
      expect(updated.isDefault, isTrue);

      final all = await repository.getMembers();
      final self = all.firstWhere(
        (m) => m.relationship == FamilyRelationship.self,
      );
      expect(self.isDefault, isFalse);
    });
  });

  group('Family persistence regressions', () {
    test(
      'Edits survive a new repository and keep optional fields cleared',
      () async {
        final repo = LocalFamilyRepository(ownerId: 'restart-test');
        final old = (await repo.getMembers()).first;
        final edited = FamilyMember(
          id: old.id,
          primaryPatientId: old.primaryPatientId,
          fullName: 'Tên đã sửa',
          relationship: old.relationship,
          bloodType: 'AB-',
          isDefault: old.isDefault,
        );
        await repo.updateMember(edited);
        final restored = await LocalFamilyRepository(ownerId: 'restart-test')
            .getMemberById(old.id);
        expect(restored!.fullName, 'Tên đã sửa');
        expect(restored.phone, isNull);
        expect(restored.medicalHistory, isNull);
        expect(restored.bloodType, 'AB-');
        expect(restored.createdAt, old.createdAt);
      },
    );

    test(
      'Concurrent writes across instances do not overwrite members',
      () async {
        final first = LocalFamilyRepository(
          initialMembers: [],
          ownerId: 'concurrent',
        );
        final second = LocalFamilyRepository(
          initialMembers: [],
          ownerId: 'concurrent',
        );
        await Future.wait([
          first.createMember(
            const FamilyMember(
              id: 'one',
              primaryPatientId: 'p',
              fullName: 'Một',
              relationship: FamilyRelationship.child,
            ),
          ),
          second.createMember(
            const FamilyMember(
              id: 'two',
              primaryPatientId: 'p',
              fullName: 'Hai',
              relationship: FamilyRelationship.child,
            ),
          ),
        ]);
        expect(
          (await first.getMembers()).map((m) => m.id),
          containsAll(['one', 'two']),
        );
      },
    );

    test(
      'Default deletion restores self and stays deleted after reopening',
      () async {
        final repo = LocalFamilyRepository();
        await repo.setDefaultMember('fam-mother-01');
        await repo.deleteMember('fam-mother-01');
        final restored = await LocalFamilyRepository().getMembers();
        expect(restored.any((m) => m.id == 'fam-mother-01'), isFalse);
        expect(restored.singleWhere((m) => m.isDefault).isSelf, isTrue);
      },
    );

    test('Accounts have separate saved family data', () async {
      final a = LocalFamilyRepository(ownerId: 'a');
      await a.updateMember(
        (await a.getMembers()).first.copyWith(fullName: 'Hồ sơ A'),
      );
      expect(
        (await LocalFamilyRepository(ownerId: 'b').getMembers()).first.fullName,
        'Nguyễn Văn An',
      );
    });

    test(
      'Active profile is refreshed after edit and chooses default when deleted',
      () async {
        final repo = LocalFamilyRepository();
        final manager = FamilyProfileManager.instance;
        await manager.loadMembers(repo);
        final mother = manager.members.firstWhere(
          (m) => m.id == 'fam-mother-01',
        );
        manager.switchMember(mother);
        await repo.updateMember(mother.copyWith(fullName: 'Mẹ đã sửa'));
        manager.updateMemberList(await repo.getMembers());
        expect(manager.activePatientName, 'Mẹ đã sửa');
        await repo.deleteMember(mother.id);
        manager.updateMemberList(await repo.getMembers());
        expect(manager.activeMember!.isDefault, isTrue);
      },
    );

    testWidgets('Editing a member survives leaving and reopening the screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FamilyMembersScreen(),
                  ),
                ),
                child: const Text('Mở gia đình'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở gia đình'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chỉnh sửa').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Nguyễn Văn An đã cập nhật',
      );
      await tester.ensureVisible(find.text('Cập nhật hồ sơ'));
      await tester.tap(find.text('Cập nhật hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Văn An đã cập nhật'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở gia đình'));
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Văn An đã cập nhật'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Family UI Widget Tests', () {
    testWidgets(
      'FamilySelectorBar renders member chips and switches active profile',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = LocalFamilyRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: FamilySelectorBar(repository: repo)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Đang xem hồ sơ:'), findsOneWidget);
        expect(find.text('Bản thân'), findsOneWidget);
        expect(find.text('Trần Thị Mai'), findsOneWidget);
        expect(find.text('Quản lý gia đình'), findsOneWidget);

        // Tap on Mother's chip to switch
        await tester.tap(find.text('Trần Thị Mai'));
        await tester.pumpAndSettle();

        expect(
          FamilyProfileManager.instance.activeMember?.fullName,
          'Trần Thị Mai',
        );
      },
    );

    testWidgets(
      'FamilyMembersScreen displays member cards, BHYT codes, and add button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = LocalFamilyRepository();

        await tester.pumpWidget(
          MaterialApp(home: FamilyMembersScreen(repository: repo)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hồ sơ Sức khỏe Gia đình'), findsOneWidget);
        expect(find.text('Chăm sóc cả gia đình'), findsOneWidget);
        expect(find.text('Nguyễn Văn An'), findsOneWidget);
        expect(find.text('Trần Thị Mai'), findsOneWidget);
        expect(find.text('Nguyễn Minh Khang'), findsOneWidget);
        expect(find.text('Thẻ BHYT: '), findsWidgets);
        expect(find.text('Thêm người thân'), findsOneWidget);
      },
    );
  });
}
