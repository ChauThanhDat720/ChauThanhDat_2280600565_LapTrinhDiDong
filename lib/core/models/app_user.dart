enum UserRole { patient, doctor, admin, unknown }

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phoneNumber,
    this.doctorId,
    this.department,
    this.createdAt,
  });
  final String id, fullName, email;
  final String? phoneNumber, doctorId, department;
  final UserRole role;
  final DateTime? createdAt;
}
