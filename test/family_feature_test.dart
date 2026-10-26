import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/family/data/family_repository.dart';
import 'package:smart_hospital/features/family/domain/family_member.dart';
import 'package:smart_hospital/features/family/presentation/family_members_screen.dart';
import 'package:smart_hospital/features/family/presentation/family_profile_manager.dart';
import 'package:smart_hospital/features/family/presentation/family_selector_bar.dart';

void main() {
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

      final self = members.firstWhere((m) => m.relationship == FamilyRelationship.self);
      final mother = members.firstWhere((m) => m.relationship == FamilyRelationship.mother);

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
      final self = members.firstWhere((m) => m.relationship == FamilyRelationship.self);

      expect(
        () async => await repository.deleteMember(self.id),
        throwsA(isA<Exception>()),
      );
    });

    test('setDefaultMember updates default flag across members', () async {
      final members = await repository.getMembers();
      final mother = members.firstWhere((m) => m.relationship == FamilyRelationship.mother);

      final updated = await repository.setDefaultMember(mother.id);
      expect(updated.isDefault, isTrue);

      final all = await repository.getMembers();
      final self = all.firstWhere((m) => m.relationship == FamilyRelationship.self);
      expect(self.isDefault, isFalse);
    });
  });

  group('Family UI Widget Tests', () {
    testWidgets('FamilySelectorBar renders member chips and switches active profile',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalFamilyRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FamilySelectorBar(repository: repo),
          ),
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

      expect(FamilyProfileManager.instance.activeMember?.fullName, 'Trần Thị Mai');
    });

    testWidgets('FamilyMembersScreen displays member cards, BHYT codes, and add button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalFamilyRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: FamilyMembersScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ Sức khỏe Gia đình'), findsOneWidget);
      expect(find.text('Chăm sóc cả gia đình'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('Trần Thị Mai'), findsOneWidget);
      expect(find.text('Nguyễn Minh Khang'), findsOneWidget);
      expect(find.text('Thẻ BHYT: '), findsWidgets);
      expect(find.text('Thêm người thân'), findsOneWidget);
    });
  });
}
