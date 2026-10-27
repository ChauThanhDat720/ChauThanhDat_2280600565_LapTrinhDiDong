import 'package:flutter/material.dart';

import '../../../core/session/patient_session.dart';
import '../data/family_repository.dart';
import '../domain/family_member.dart';

class FamilyProfileManager extends ChangeNotifier {
  FamilyProfileManager._();
  static final FamilyProfileManager instance = FamilyProfileManager._();

  FamilyMember? _activeMember;
  List<FamilyMember> _members = [];
  bool _isLoading = false;
  String _loadedForEmail = '';

  FamilyMember? get activeMember => _activeMember;
  List<FamilyMember> get members => List.unmodifiable(_members);
  bool get isLoading => _isLoading;

  String get activePatientName =>
      _activeMember?.fullName ?? PatientSession.instance.name;
  String get activePatientId =>
      _activeMember?.id ?? PatientSession.instance.patientId;
  bool get isViewingSelf => _activeMember == null || _activeMember!.isSelf;

  void _syncToSession() {
    if (_activeMember != null && !_activeMember!.isSelf) {
      PatientSession.instance.setActiveFamilyProfile(
        memberId: _activeMember!.id,
        memberName: _activeMember!.fullName,
        isSelf: false,
      );
    } else {
      PatientSession.instance.resetActiveFamilyProfile();
    }
  }

  void reset() {
    _activeMember = null;
    _members = [];
    _loadedForEmail = '';
    PatientSession.instance.resetActiveFamilyProfile();
    notifyListeners();
  }

  Future<void> loadMembers(FamilyRepository repository) async {
    final currentEmail = PatientSession.instance.email.trim().toLowerCase();
    if (_loadedForEmail != currentEmail) {
      _activeMember = null;
      _members = [];
      _loadedForEmail = currentEmail;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final items = await repository.getMembers();
      _members = items;
      if (_activeMember != null &&
          _members.any((m) => m.id == _activeMember!.id)) {
        _activeMember = _members.firstWhere((m) => m.id == _activeMember!.id);
      } else {
        final selfMember = _members.where((m) => m.isSelf);
        final def = _members.where((m) => m.isDefault);
        if (selfMember.isNotEmpty) {
          _activeMember = selfMember.first;
        } else if (def.isNotEmpty) {
          _activeMember = def.first;
        } else {
          _activeMember = null;
        }
      }
      _syncToSession();
    } catch (_) {
      // keep existing state
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectSelf() {
    final selfMember = _members.where((m) => m.isSelf).firstOrNull;
    _activeMember = selfMember;
    _syncToSession();
    notifyListeners();
  }

  void switchMember(FamilyMember member) {
    if (_activeMember?.id != member.id) {
      _activeMember = member;
      _syncToSession();
      notifyListeners();
    }
  }

  void updateMemberList(
    List<FamilyMember> updatedList, {
    FamilyMember? newActive,
  }) {
    final activeId = newActive?.id ?? _activeMember?.id;
    _members = List.of(updatedList);
    if (activeId == null) {
      _activeMember = _members.where((m) => m.isSelf).firstOrNull;
    } else {
      final selected = _members.where((m) => m.id == activeId);
      final selfMember = _members.where((m) => m.isSelf);
      _activeMember = selected.isNotEmpty
          ? selected.first
          : (selfMember.isNotEmpty ? selfMember.first : null);
    }
    _syncToSession();
    notifyListeners();
  }
}
