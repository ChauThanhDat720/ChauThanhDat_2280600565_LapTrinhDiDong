import '../../../core/network/api_client.dart';
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
  LocalFamilyRepository({List<FamilyMember>? initialMembers}) {
    if (initialMembers != null) {
      _members.addAll(initialMembers);
    } else {
      _seedDefaultMembers();
    }
  }

  final List<FamilyMember> _members = [];

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
    return List<FamilyMember>.from(_members);
  }

  @override
  Future<FamilyMember?> getMemberById(String id) async {
    final found = _members.where((m) => m.id == id);
    return found.isNotEmpty ? found.first : null;
  }

  @override
  Future<FamilyMember> createMember(FamilyMember member) async {
    final newId = member.id.isNotEmpty ? member.id : 'fam-${DateTime.now().millisecondsSinceEpoch}';
    final created = member.copyWith(
      id: newId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (created.isDefault) {
      for (int i = 0; i < _members.length; i++) {
        _members[i] = _members[i].copyWith(isDefault: false);
      }
    }

    _members.add(created);
    return created;
  }

  @override
  Future<FamilyMember> updateMember(FamilyMember member) async {
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index == -1) {
      throw Exception('Không tìm thấy thành viên để cập nhật.');
    }

    if (member.isDefault) {
      for (int i = 0; i < _members.length; i++) {
        _members[i] = _members[i].copyWith(isDefault: false);
      }
    }

    final updated = member.copyWith(updatedAt: DateTime.now());
    _members[index] = updated;
    return updated;
  }

  @override
  Future<bool> deleteMember(String id) async {
    final index = _members.indexWhere((m) => m.id == id);
    if (index == -1) return false;

    if (_members[index].isSelf) {
      throw Exception('Không thể xóa hồ sơ chính của Bản thân.');
    }

    _members.removeAt(index);
    return true;
  }

  @override
  Future<FamilyMember> setDefaultMember(String memberId) async {
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index == -1) {
      throw Exception('Không tìm thấy thành viên.');
    }

    for (int i = 0; i < _members.length; i++) {
      _members[i] = _members[i].copyWith(isDefault: _members[i].id == memberId);
    }

    return _members[index];
  }
}

class RemoteFamilyRepository implements FamilyRepository {
  RemoteFamilyRepository([
    this._client,
    LocalFamilyRepository? fallback,
  ]) : _fallback = fallback ?? LocalFamilyRepository();

  final ApiClient? _client;
  final LocalFamilyRepository _fallback;

  @override
  Future<List<FamilyMember>> getMembers({String? primaryPatientId}) async {
    try {
      if (_client != null) {
        final res = await _client.get('/family/members');
        if (res is Map<String, dynamic> && res['items'] is List) {
          return (res['items'] as List)
              .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.getMembers(primaryPatientId: primaryPatientId);
  }

  @override
  Future<FamilyMember?> getMemberById(String id) async {
    try {
      if (_client != null) {
        final res = await _client.get('/family/members/$id');
        if (res is Map<String, dynamic>) {
          return FamilyMember.fromJson(res);
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.getMemberById(id);
  }

  @override
  Future<FamilyMember> createMember(FamilyMember member) async {
    try {
      if (_client != null) {
        final res = await _client.post('/family/members', body: member.toJson());
        if (res is Map<String, dynamic>) {
          return FamilyMember.fromJson(res);
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.createMember(member);
  }

  @override
  Future<FamilyMember> updateMember(FamilyMember member) async {
    try {
      if (_client != null) {
        final res = await _client.patch('/family/members/${member.id}', body: member.toJson());
        if (res is Map<String, dynamic>) {
          return FamilyMember.fromJson(res);
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.updateMember(member);
  }

  @override
  Future<bool> deleteMember(String id) async {
    try {
      if (_client != null) {
        final res = await _client.delete('/family/members/$id');
        if (res is Map<String, dynamic> && res['success'] == true) {
          return true;
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.deleteMember(id);
  }

  @override
  Future<FamilyMember> setDefaultMember(String memberId) async {
    try {
      if (_client != null) {
        final res = await _client.patch('/family/members/$memberId/default', body: {});
        if (res is Map<String, dynamic>) {
          return FamilyMember.fromJson(res);
        }
      }
    } catch (_) {
      // Fallback local
    }
    return _fallback.setDefaultMember(memberId);
  }
}
