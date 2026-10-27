import '../../../core/network/api_client.dart';
import '../../../core/session/patient_session.dart';
import '../../../core/storage/local_json_storage.dart';
import '../domain/family_member.dart';

abstract class FamilyRepository {
  Future<List<FamilyMember>> getMembers({String? primaryPatientId});
  Future<FamilyMember?> getMemberById(String id);
  Future<FamilyMember> createMember(FamilyMember member);
  Future<FamilyMember> updateMember(FamilyMember member);
  Future<bool> deleteMember(String id);
  Future<FamilyMember> setDefaultMember(String memberId);
}

class LocalFamilyRepository implements FamilyRepository {
  LocalFamilyRepository({List<FamilyMember>? initialMembers, String? ownerId})
    : _ownerId =
          ownerId ??
          (PatientSession.instance.email.isEmpty
              ? 'local-family'
              : PatientSession.instance.email.toLowerCase()) {
    if (initialMembers != null) {
      _members.addAll(initialMembers);
    } else {
      _seedDefaultMembers();
    }
  }

  final List<FamilyMember> _members = [];
  final String _ownerId;
  String get _storageKey => 'family_members_v1:$_ownerId';

  Future<List<FamilyMember>> _readMembers() async {
    final saved = await LocalJsonStorage.read(_storageKey);
    return saved == null
        ? List.of(_members)
        : saved.map(FamilyMember.fromJson).toList();
  }

  Future<T> _change<T>(T Function(List<FamilyMember>) update) =>
      LocalJsonStorage.exclusive(_storageKey, () async {
        final members = await _readMembers();
        final result = update(members);
        await LocalJsonStorage.write(
          _storageKey,
          members.map((m) => m.toJson()).toList(),
        );
        _members
          ..clear()
          ..addAll(members);
        return result;
      });

  void _seedDefaultMembers() {
    final now = DateTime.now();
    _members.addAll([
      FamilyMember(
        id: 'fam-self-01',
        primaryPatientId: 'test-patient-sub-123',
        fullName: 'Nguyễn Văn An',
        relationship: FamilyRelationship.self,
        dateOfBirth: DateTime(1992, 4, 12),
        gender: 'Nam',
        phone: '0912345678',
        bhytCode: 'DN4791234567890',
        identityCard: '079092001234',
        bloodType: 'O+',
        medicalHistory: 'Không có tiền sử dị ứng thuốc',
        isDefault: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      FamilyMember(
        id: 'fam-mother-01',
        primaryPatientId: 'test-patient-sub-123',
        fullName: 'Trần Thị Mai',
        relationship: FamilyRelationship.mother,
        dateOfBirth: DateTime(1965, 8, 15),
        gender: 'Nữ',
        phone: '0908765432',
        bhytCode: 'GD4798765432100',
        identityCard: '079165005678',
        bloodType: 'A+',
        medicalHistory: 'Tăng huyết áp vô căn 5 năm, thoái hóa khớp gối',
        isDefault: false,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      FamilyMember(
        id: 'fam-child-01',
        primaryPatientId: 'test-patient-sub-123',
        fullName: 'Nguyễn Minh Khang',
        relationship: FamilyRelationship.child,
        dateOfBirth: DateTime(2018, 5, 10),
        gender: 'Nam',
        phone: '0912345678',
        bhytCode: 'TE1791234567800',
        identityCard: '079218009876',
        bloodType: 'O+',
        medicalHistory: 'Dị ứng nhẹ với kháng sinh Amoxicillin',
        isDefault: false,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ]);
  }

  @override
  Future<List<FamilyMember>> getMembers({String? primaryPatientId}) async {
    final members = await _readMembers();
    return primaryPatientId == null
        ? members
        : members.where((m) => m.primaryPatientId == primaryPatientId).toList();
  }

  @override
  Future<FamilyMember?> getMemberById(String id) async {
    final members = await _readMembers();
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  @override
  Future<FamilyMember> createMember(FamilyMember member) => _change((members) {
    if (member.fullName.trim().isEmpty) {
      throw ArgumentError('Vui lòng nhập họ tên.');
    }
    final created = member.copyWith(
      id: member.id.isEmpty
          ? 'fam-${DateTime.now().microsecondsSinceEpoch}'
          : member.id,
      fullName: member.fullName.trim(),
      isDefault: members.isEmpty || member.isDefault,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (members.any((m) => m.id == created.id)) {
      throw StateError('Thành viên đã tồn tại.');
    }
    if (created.isDefault) {
      for (var i = 0; i < members.length; i++) {
        members[i] = members[i].copyWith(isDefault: false);
      }
    }
    members.add(created);
    return created;
  });

  @override
  Future<FamilyMember> updateMember(FamilyMember member) => _change((members) {
    final index = members.indexWhere((m) => m.id == member.id);
    if (index < 0) throw StateError('Không tìm thấy thành viên để cập nhật.');
    if (member.fullName.trim().isEmpty) {
      throw ArgumentError('Vui lòng nhập họ tên.');
    }
    final existing = members[index];
    if (existing.isSelf != member.isSelf) {
      throw StateError(
        'Không thể đổi hồ sơ bản thân thành người thân hoặc ngược lại.',
      );
    }
    final updated = member.copyWith(
      fullName: member.fullName.trim(),
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    if (updated.isDefault) {
      for (var i = 0; i < members.length; i++) {
        members[i] = members[i].copyWith(isDefault: false);
      }
    }
    members[index] = updated;
    return updated;
  });

  @override
  Future<bool> deleteMember(String id) => _change((members) {
    final index = members.indexWhere((m) => m.id == id);
    if (index < 0) return false;
    if (members[index].isSelf) {
      throw Exception('Không thể xóa hồ sơ chính của Bản thân.');
    }
    final wasDefault = members[index].isDefault;
    members.removeAt(index);
    if (wasDefault && members.isNotEmpty) {
      final fallback = members.indexWhere((m) => m.isSelf);
      final target = fallback < 0 ? 0 : fallback;
      members[target] = members[target].copyWith(isDefault: true);
    }
    return true;
  });

  @override
  Future<FamilyMember> setDefaultMember(String memberId) => _change((members) {
    final index = members.indexWhere((m) => m.id == memberId);
    if (index < 0) throw StateError('Không tìm thấy thành viên.');
    for (var i = 0; i < members.length; i++) {
      members[i] = members[i].copyWith(isDefault: members[i].id == memberId);
    }
    return members[index];
  });
}

class RemoteFamilyRepository implements FamilyRepository {
  RemoteFamilyRepository(this._client);
  final ApiClient _client;
  @override
  Future<List<FamilyMember>> getMembers({String? primaryPatientId}) async {
    final result = await _client.get('/family/members') as Map<String, dynamic>;
    return (result['items'] as List)
        .map((m) => FamilyMember.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FamilyMember?> getMemberById(String id) async => FamilyMember.fromJson(
    await _client.get('/family/members/${Uri.encodeComponent(id)}')
        as Map<String, dynamic>,
  );
  @override
  Future<FamilyMember> createMember(FamilyMember member) async =>
      FamilyMember.fromJson(
        await _client.post('/family/members', body: member.toJson())
            as Map<String, dynamic>,
      );
  @override
  Future<FamilyMember> updateMember(FamilyMember member) async =>
      FamilyMember.fromJson(
        await _client.patch(
          '/family/members/${Uri.encodeComponent(member.id)}',
          body: member.toJson(),
        ) as Map<String, dynamic>,
      );
  @override
  Future<bool> deleteMember(String id) async =>
      (await _client.delete(
        '/family/members/${Uri.encodeComponent(id)}',
      ))['success'] ==
      true;
  @override
  Future<FamilyMember> setDefaultMember(String memberId) async =>
      FamilyMember.fromJson(
        await _client.patch(
          '/family/members/${Uri.encodeComponent(memberId)}/default',
          body: {},
        ) as Map<String, dynamic>,
      );
}
