class PatientProfile {
  const PatientProfile({
    this.patientId,
    this.cognitoUserId,
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.createdAt,
    this.updatedAt,
  });

  final String? patientId;
  final String? cognitoUserId;
  final String name;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final String address;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PatientProfile copyWith({
    String? name,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) => PatientProfile(
    patientId: patientId,
    cognitoUserId: cognitoUserId,
    name: name ?? this.name,
    email: email,
    phone: phone ?? this.phone,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: gender ?? this.gender,
    address: address ?? this.address,
    emergencyContactName: emergencyContactName ?? this.emergencyContactName,
    emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toJson() => {
    if (patientId != null) 'patientId': patientId,
    if (cognitoUserId != null) 'cognitoUserId': cognitoUserId,
    'name': name,
    'email': email,
    'phone': phone,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'address': address,
    'emergencyContactName': emergencyContactName,
    'emergencyContactPhone': emergencyContactPhone,
  };

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
    patientId: json['patientId'] as String?,
    cognitoUserId: json['cognitoUserId'] as String?,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    dateOfBirth: json['dateOfBirth'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    address: json['address'] as String? ?? '',
    emergencyContactName: json['emergencyContactName'] as String? ?? '',
    emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
    createdAt: json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
    updatedAt: json['updatedAt'] is String
        ? DateTime.tryParse(json['updatedAt'] as String)
        : null,
  );
}
