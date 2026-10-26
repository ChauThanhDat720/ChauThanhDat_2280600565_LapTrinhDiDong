import 'package:flutter/material.dart';

enum FamilyRelationship {
  self,
  father,
  mother,
  spouse,
  child,
  grandparent,
  other;

  String get label => switch (this) {
        self => 'Bản thân',
        father => 'Bố / Cha',
        mother => 'Mẹ',
        spouse => 'Vợ / Chồng',
        child => 'Con cái',
        grandparent => 'Ông / Bà',
        other => 'Người thân khác',
      };

  IconData get icon => switch (this) {
        self => Icons.person_rounded,
        father => Icons.elderly_rounded,
        mother => Icons.elderly_woman_rounded,
        spouse => Icons.favorite_rounded,
        child => Icons.child_care_rounded,
        grandparent => Icons.family_restroom_rounded,
        other => Icons.group_rounded,
      };

  Color get color => switch (this) {
        self => const Color(0xFF0284C7),
        father => const Color(0xFF2563EB),
        mother => const Color(0xFFD946EF),
        spouse => const Color(0xFFE11D48),
        child => const Color(0xFF16A34A),
        grandparent => const Color(0xFFCA8A04),
        other => const Color(0xFF64748B),
      };

  static FamilyRelationship fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'father':
        return FamilyRelationship.father;
      case 'mother':
        return FamilyRelationship.mother;
      case 'spouse':
        return FamilyRelationship.spouse;
      case 'child':
        return FamilyRelationship.child;
      case 'grandparent':
        return FamilyRelationship.grandparent;
      case 'other':
        return FamilyRelationship.other;
      default:
        return FamilyRelationship.self;
    }
  }
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.primaryPatientId,
    required this.fullName,
    this.relationship = FamilyRelationship.self,
    this.dateOfBirth,
    this.gender = 'Nam',
    this.phone,
    this.bhytCode,
    this.identityCard,
    this.bloodType,
    this.medicalHistory,
    this.avatar,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String primaryPatientId;
  final String fullName;
  final FamilyRelationship relationship;
  final DateTime? dateOfBirth;
  final String gender;
  final String? phone;
  final String? bhytCode;
  final String? identityCard;
  final String? bloodType;
  final String? medicalHistory;
  final String? avatar;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSelf => relationship == FamilyRelationship.self;

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years >= 0 ? years : 0;
  }

  String get formattedAge {
    final a = age;
    return a != null ? '$a tuổi' : 'Chưa rõ tuổi';
  }

  String get relationshipLabel => relationship.label;
  IconData get relationshipIcon => relationship.icon;
  Color get avatarColor => relationship.color;

  FamilyMember copyWith({
    String? id,
    String? primaryPatientId,
    String? fullName,
    FamilyRelationship? relationship,
    DateTime? dateOfBirth,
    String? gender,
    String? phone,
    String? bhytCode,
    String? identityCard,
    String? bloodType,
    String? medicalHistory,
    String? avatar,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      primaryPatientId: primaryPatientId ?? this.primaryPatientId,
      fullName: fullName ?? this.fullName,
      relationship: relationship ?? this.relationship,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      bhytCode: bhytCode ?? this.bhytCode,
      identityCard: identityCard ?? this.identityCard,
      bloodType: bloodType ?? this.bloodType,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      avatar: avatar ?? this.avatar,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String? ?? '',
      primaryPatientId: json['primary_patient_id'] as String? ?? json['primaryPatientId'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      relationship: FamilyRelationship.fromString(json['relationship'] as String?),
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : json['dateOfBirth'] != null
              ? DateTime.tryParse(json['dateOfBirth'].toString())
              : null,
      gender: json['gender'] as String? ?? 'Nam',
      phone: json['phone'] as String?,
      bhytCode: json['bhyt_code'] as String? ?? json['bhytCode'] as String?,
      identityCard: json['identity_card'] as String? ?? json['identityCard'] as String?,
      bloodType: json['blood_type'] as String? ?? json['bloodType'] as String?,
      medicalHistory: json['medical_history'] as String? ?? json['medicalHistory'] as String?,
      avatar: json['avatar'] as String?,
      isDefault: json['is_default'] == 1 || json['is_default'] == true || json['isDefault'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'primary_patient_id': primaryPatientId,
        'full_name': fullName,
        'relationship': relationship.name,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'gender': gender,
        'phone': phone,
        'bhyt_code': bhytCode,
        'identity_card': identityCard,
        'blood_type': bloodType,
        'medical_history': medicalHistory,
        'avatar': avatar,
        'is_default': isDefault ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
