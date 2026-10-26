import 'package:flutter/material.dart';

import '../data/family_repository.dart';
import '../domain/family_member.dart';

class FamilyProfileManager extends ChangeNotifier {
  FamilyProfileManager._();
  static final FamilyProfileManager instance = FamilyProfileManager._();

  FamilyMember? _activeMember;
  List<FamilyMember> _members = [];
  bool _isLoading = false;

  FamilyMember? get activeMember => _activeMember;
  List<FamilyMember> get members => List.unmodifiable(_members);
  bool get isLoading => _isLoading;

  String get activePatientName => _activeMember?.fullName ?? 'Nguyễn Văn An';
  String get activePatientId => _activeMember?.id ?? 'test-patient-sub-123';
  bool get isViewingSelf => _activeMember?.isSelf ?? true;

  Future<void> loadMembers(FamilyRepository repository) async {
    _isLoading = true;
    notifyListeners();
    try {
      final items = await repository.getMembers();
      _members = items;
      if (_activeMember == null || !_members.any((m) => m.id == _activeMember!.id)) {
        final def = _members.where((m) => m.isDefault);
        _activeMember = def.isNotEmpty ? def.first : (_members.isNotEmpty ? _members.first : null);
      } else {
        _activeMember = _members.firstWhere((m) => m.id == _activeMember!.id);
      }
    } catch (_) {
      // keep existing state
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void switchMember(FamilyMember member) {
    if (_activeMember?.id != member.id) {
      _activeMember = member;
      notifyListeners();
    }
  }

  void updateMemberList(List<FamilyMember> updatedList, {FamilyMember? newActive}) {
    _members = updatedList;
    if (newActive != null) {
      _activeMember = newActive;
    } else if (_activeMember != null && !_members.any((m) => m.id == _activeMember!.id)) {
      _activeMember = _members.isNotEmpty ? _members.first : null;
    }
    notifyListeners();
  }
}
