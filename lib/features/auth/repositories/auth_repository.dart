import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_user.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/session/patient_session.dart';

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SignUpOutcome {
  const SignUpOutcome({required this.needsConfirmation});
  final bool needsConfirmation;
}

abstract interface class AuthRepository {
  bool get isDemo;
  Future<SignUpOutcome> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? address,
  });
  Future<void> confirmSignUp(String email, String code);
  Future<void> resendSignUpCode(String email);
  Future<AppUser?> signIn(String email, String password, {String? demoName});
  Future<AppUser?> restoreSession();
  Future<void> signOut();
  Future<void> startPasswordReset(String email);
  Future<void> confirmPasswordReset(String email, String code, String password);
}

class DoctorAccountInfo {
  const DoctorAccountInfo({
    required this.id,
    required this.name,
    required this.department,
    required this.specialty,
    required this.phone,
    required this.passwords,
  });
  final String id;
  final String name;
  final String department;
  final String specialty;
  final String phone;
  final List<String> passwords;
}

class LocalAuthRepository implements AuthRepository {
  const LocalAuthRepository();

  static const String _registeredAccountsKey = 'local_registered_accounts_v1';

  static const Map<String, DoctorAccountInfo> doctorAccounts = {
    'doctor.linh@hospital.com': DoctorAccountInfo(
      id: 'dr-linh',
      name: 'BS. Trần Thảo Linh',
      department: 'Khoa Tim mạch',
      specialty: 'Bác sĩ tim mạch',
      phone: '0901234567',
      passwords: ['Doctor@123', '123456', 'Bacsi@123'],
    ),
    'doctor.duc@hospital.com': DoctorAccountInfo(
      id: 'dr-duc',
      name: 'BS. Nguyễn Đức Minh',
      department: 'Khoa Nhi',
      specialty: 'Bác sĩ nhi khoa',
      phone: '0902345678',
      passwords: ['Doctor@123', '123456', 'Bacsi@123'],
    ),
    'doctor.lan@hospital.com': DoctorAccountInfo(
      id: 'dr-lan',
      name: 'BS. Phạm Ngọc Lan',
      department: 'Khoa Da liễu',
      specialty: 'Bác sĩ da liễu',
      phone: '0903456789',
      passwords: ['Doctor@123', '123456', 'Bacsi@123'],
    ),
    'doctor.tuan@hospital.com': DoctorAccountInfo(
      id: 'dr-tuan',
      name: 'BS. Lê Anh Tuấn',
      department: 'Khoa Nội tổng quát',
      specialty: 'Bác sĩ nội tổng quát',
      phone: '0904567890',
      passwords: ['Doctor@123', '123456', 'Bacsi@123'],
    ),
    'doctor.huong@hospital.com': DoctorAccountInfo(
      id: 'dr-huong',
      name: 'BS. Võ Thu Hương',
      department: 'Khoa Tai Mũi Họng',
      specialty: 'Bác sĩ tai mũi họng',
      phone: '0905678901',
      passwords: ['Doctor@123', '123456', 'Bacsi@123'],
    ),
    'doctor.phong@hospital.com': DoctorAccountInfo(
      id: 'dr-phong',
      name: 'BS. Đặng Hải Phong',
      department: 'Khoa Thần kinh',
      specialty: 'Bác sĩ thần kinh',
      phone: '0906789012',
      passwords: ['Doctor@123', '123456', 'Bacsi@123'],
    ),
    'doctor.mai@hospital.com': DoctorAccountInfo(
      id: 'dr-mai',
      name: 'BS. Bùi Thanh Mai',
      department: 'Khoa Chấn thương chỉnh hình',
      specialty: 'Bác sĩ cơ xương khớp',
      phone: '0907890123',
      passwords: ['Doctor@123', '123456', 'Bacsi@123'],
    ),
    'doctor.khanh@hospital.com': DoctorAccountInfo(
      id: 'dr-khanh',
      name: 'BS. Hoàng Khánh Vy',
      department: 'Khoa Răng Hàm Mặt',
      specialty: 'Bác sĩ nha khoa',
      phone: '0908901234',
      passwords: ['Doctor@123', '123456', 'Bacsi@123'],
    ),
  };

  @override
  bool get isDemo => false;

  @override
  Future<SignUpOutcome> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? address,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (doctorAccounts.containsKey(cleanEmail) || cleanEmail == 'admin@hospital.com') {
      throw const AuthRepositoryException(
        'Email này thuộc về cán bộ bệnh viện. Vui lòng sử dụng email cá nhân để đăng ký.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_registeredAccountsKey);
    final List<dynamic> accounts = rawJson != null
        ? (jsonDecode(rawJson) as List<dynamic>)
        : <dynamic>[];

    final exists = accounts.any((a) => (a['email'] as String).toLowerCase() == cleanEmail);
    if (exists) {
      throw const AuthRepositoryException(
        'Email này đã được đăng ký tài khoản. Vui lòng đăng nhập.',
      );
    }

    final newAccount = {
      'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
      'email': cleanEmail,
      'password': password,
      'name': name.trim(),
      'phone': phone?.trim() ?? '',
      'dateOfBirth': dateOfBirth?.trim() ?? '',
      'gender': gender?.trim() ?? '',
      'address': address?.trim() ?? '',
      'role': 'patient',
      'createdAt': DateTime.now().toIso8601String(),
    };
    accounts.add(newAccount);
    await prefs.setString(_registeredAccountsKey, jsonEncode(accounts));

    await PatientSession.instance.signIn(
      name: name,
      email: cleanEmail,
      phone: phone ?? '',
      dateOfBirth: dateOfBirth ?? '',
      gender: gender ?? '',
      address: address ?? '',
      role: 'patient',
    );
    return const SignUpOutcome(needsConfirmation: false);
  }

  @override
  Future<void> confirmSignUp(String email, String code) async {}

  @override
  Future<void> resendSignUpCode(String email) async {}

  @override
  Future<AppUser?> signIn(
    String email,
    String password, {
    String? demoName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check Doctor Accounts
    final doctor = doctorAccounts[cleanEmail];
    if (doctor != null) {
      if (!doctor.passwords.contains(password)) {
        throw const AuthRepositoryException(
          'Mật khẩu không chính xác. Vui lòng kiểm tra lại mật khẩu Bác sĩ.',
        );
      }
      await PatientSession.instance.signIn(
        name: doctor.name,
        email: cleanEmail,
        phone: doctor.phone,
        role: 'doctor',
        doctorId: doctor.id,
        department: doctor.department,
      );
      return AppUser(
        id: doctor.id,
        fullName: doctor.name,
        email: cleanEmail,
        phoneNumber: doctor.phone,
        role: UserRole.doctor,
        doctorId: doctor.id,
        department: doctor.department,
      );
    }

    // 2. Check Admin Account
    if (cleanEmail == 'admin@hospital.com') {
      if (!['Admin@123', '123456'].contains(password)) {
        throw const AuthRepositoryException(
          'Mật khẩu không chính xác. Vui lòng kiểm tra lại.',
        );
      }
      await PatientSession.instance.signIn(
        name: 'Quản trị viên Hệ thống',
        email: cleanEmail,
        role: 'admin',
      );
      return const AppUser(
        id: 'admin-01',
        fullName: 'Quản trị viên Hệ thống',
        email: 'admin@hospital.com',
        role: UserRole.admin,
      );
    }

    // 3. Check Default Pre-seeded Patients
    if (cleanEmail == 'patient.an@hospital.com' ||
        cleanEmail == 'patient.mai@hospital.com' ||
        cleanEmail == 'test.user@hospital.com') {
      if (!['Patient@123', '123456'].contains(password)) {
        throw const AuthRepositoryException(
          'Mật khẩu không chính xác. Vui lòng kiểm tra lại.',
        );
      }
      final defaultName = cleanEmail == 'patient.an@hospital.com'
          ? 'Nguyễn Văn An'
          : cleanEmail == 'patient.mai@hospital.com'
              ? 'Trần Thị Mai'
              : (demoName?.isNotEmpty == true ? demoName! : 'test.user');
      final defaultPhone = cleanEmail == 'patient.an@hospital.com'
          ? '0912345678'
          : cleanEmail == 'patient.mai@hospital.com'
              ? '0923456789'
              : '0900000000';
      await PatientSession.instance.signIn(
        name: defaultName,
        email: cleanEmail,
        phone: defaultPhone,
        role: 'patient',
      );
      return AppUser(
        id: 'local-$cleanEmail',
        fullName: defaultName,
        email: cleanEmail,
        phoneNumber: defaultPhone,
        role: UserRole.patient,
      );
    }

    // 4. Check Dynamically Registered Accounts
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_registeredAccountsKey);
    final List<dynamic> accounts = rawJson != null
        ? (jsonDecode(rawJson) as List<dynamic>)
        : <dynamic>[];
    final match = accounts.cast<Map<String, dynamic>?>().firstWhere(
      (acc) => acc?['email']?.toString().toLowerCase() == cleanEmail,
      orElse: () => null,
    );

    if (match != null) {
      if (match['password'] != password) {
        throw const AuthRepositoryException(
          'Mật khẩu không chính xác. Vui lòng kiểm tra lại.',
        );
      }
      final name = match['name'] as String? ?? cleanEmail.split('@').first;
      final phone = match['phone'] as String? ?? '';
      final dob = match['dateOfBirth'] as String? ?? '';
      final gender = match['gender'] as String? ?? '';
      final address = match['address'] as String? ?? '';
      await PatientSession.instance.signIn(
        name: name,
        email: cleanEmail,
        phone: phone,
        dateOfBirth: dob,
        gender: gender,
        address: address,
        role: 'patient',
      );
      return AppUser(
        id: match['id'] as String? ?? 'local-$cleanEmail',
        fullName: name,
        email: cleanEmail,
        phoneNumber: phone,
        role: UserRole.patient,
      );
    }

    throw const AuthRepositoryException(
      'Tài khoản email này chưa được đăng ký trong hệ thống. Vui lòng đăng ký tài khoản mới.',
    );
  }

  @override
  Future<AppUser?> restoreSession() async {
    await PatientSession.instance.restore();
    return PatientSession.instance.isLoggedIn ? _user() : null;
  }

  AppUser _user() {
    final email = PatientSession.instance.email.toLowerCase();
    final roleStr = PatientSession.instance.role;
    final role = roleStr == 'doctor' || email.contains('doctor')
        ? UserRole.doctor
        : roleStr == 'admin' || email.contains('admin')
        ? UserRole.admin
        : UserRole.patient;
    return AppUser(
      id: PatientSession.instance.doctorId.isNotEmpty
          ? PatientSession.instance.doctorId
          : 'local-${PatientSession.instance.email}',
      fullName: PatientSession.instance.name,
      email: PatientSession.instance.email,
      phoneNumber: PatientSession.instance.phone,
      role: role,
      doctorId: PatientSession.instance.doctorId.isNotEmpty
          ? PatientSession.instance.doctorId
          : (role == UserRole.doctor ? 'dr-linh' : null),
      department: PatientSession.instance.department.isNotEmpty
          ? PatientSession.instance.department
          : (role == UserRole.doctor ? 'Khoa Tim mạch' : null),
    );
  }

  @override
  Future<void> signOut() => PatientSession.instance.clear();

  @override
  Future<void> startPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final isDoctor = doctorAccounts.containsKey(cleanEmail);
    final isAdmin = cleanEmail == 'admin@hospital.com';
    final isPreSeeded = cleanEmail == 'patient.an@hospital.com' || cleanEmail == 'patient.mai@hospital.com';

    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_registeredAccountsKey);
    final List<dynamic> accounts = rawJson != null
        ? (jsonDecode(rawJson) as List<dynamic>)
        : <dynamic>[];
    final isRegistered = accounts.any((a) => (a['email'] as String).toLowerCase() == cleanEmail);

    if (!isDoctor && !isAdmin && !isPreSeeded && !isRegistered) {
      throw const AuthRepositoryException(
        'Email này chưa được đăng ký trong hệ thống.',
      );
    }
  }

  @override
  Future<void> confirmPasswordReset(
    String email,
    String code,
    String password,
  ) async {
    final cleanEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_registeredAccountsKey);
    final List<dynamic> accounts = rawJson != null
        ? (jsonDecode(rawJson) as List<dynamic>)
        : <dynamic>[];
    final idx = accounts.indexWhere((a) => (a['email'] as String).toLowerCase() == cleanEmail);
    if (idx != -1) {
      accounts[idx]['password'] = password;
      await prefs.setString(_registeredAccountsKey, jsonEncode(accounts));
    }
  }
}

class CognitoAuthRepository implements AuthRepository {
  CognitoAuthRepository(this._service);
  final AuthService _service;
  @override
  bool get isDemo => false;
  Future<void> _ready() async {
    if (!await _service.initialize()) {
      throw const AuthRepositoryException(
        'Dịch vụ đăng nhập trực tuyến chưa được cấu hình.',
      );
    }
  }

  @override
  Future<SignUpOutcome> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? address,
  }) async {
    await _ready();
    final attrs = <AuthUserAttributeKey, String>{
      AuthUserAttributeKey.email: email,
      AuthUserAttributeKey.name: name,
    };
    if (phone?.isNotEmpty ?? false) {
      final trimmed = phone!.trim().replaceAll(RegExp(r'[\s.-]'), '');
      final normalized = trimmed.startsWith('0')
          ? '+84${trimmed.substring(1)}'
          : trimmed;
      if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
        throw const AuthRepositoryException(
          'Số điện thoại không hợp lệ. Dùng 09... hoặc định dạng +84...',
        );
      }
      attrs[AuthUserAttributeKey.phoneNumber] = normalized;
    }
    final r = await Amplify.Auth.signUp(
      username: email,
      password: password,
      options: SignUpOptions(userAttributes: attrs),
    );
    return SignUpOutcome(needsConfirmation: !r.isSignUpComplete);
  }

  @override
  Future<void> confirmSignUp(String email, String code) async {
    await _ready();
    await Amplify.Auth.confirmSignUp(username: email, confirmationCode: code);
  }

  @override
  Future<void> resendSignUpCode(String email) async {
    await _ready();
    await Amplify.Auth.resendSignUpCode(username: email);
  }

  @override
  Future<AppUser?> signIn(
    String email,
    String password, {
    String? demoName,
  }) async {
    await _ready();
    final existing = await Amplify.Auth.fetchAuthSession();
    if (existing.isSignedIn) await Amplify.Auth.signOut();
    final r = await Amplify.Auth.signIn(username: email, password: password);
    if (!r.isSignedIn) {
      throw const AuthRepositoryException(
        'Tài khoản cần hoàn tất bước xác thực.',
      );
    }
    return _current();
  }

  @override
  Future<AppUser?> restoreSession() async {
    await _ready();
    final s = await Amplify.Auth.fetchAuthSession();
    return s.isSignedIn ? _current() : null;
  }

  @override
  Future<void> signOut() async {
    await _ready();
    await Amplify.Auth.signOut();
    await PatientSession.instance.clear();
  }

  @override
  Future<void> startPasswordReset(String email) async {
    await _ready();
    await Amplify.Auth.resetPassword(username: email);
  }

  @override
  Future<void> confirmPasswordReset(
    String email,
    String code,
    String password,
  ) async {
    await _ready();
    await Amplify.Auth.confirmResetPassword(
      username: email,
      confirmationCode: code,
      newPassword: password,
    );
  }

  Future<AppUser> _current() async {
    final user = await Amplify.Auth.getCurrentUser();
    final attributes = await Amplify.Auth.fetchUserAttributes();
    final a = {
      for (final attribute in attributes)
        attribute.userAttributeKey: attribute.value,
    };
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    final groups = session
        .userPoolTokensResult
        .valueOrNull
        ?.accessToken
        .claims
        .customClaims['cognito:groups'];
    final roles = groups is List
        ? groups.cast<Object?>().map((e) => '$e')
        : '$groups'.split(',');
    final role = roles.contains('admins')
        ? UserRole.admin
        : roles.contains('doctors')
        ? UserRole.doctor
        : roles.contains('patients')
        ? UserRole.patient
        : UserRole.unknown;
    await PatientSession.instance.signIn(
      name: a[AuthUserAttributeKey.name] ?? '',
      email: a[AuthUserAttributeKey.email] ?? user.username,
      role: role == UserRole.doctor ? 'doctor' : 'patient',
    );
    return AppUser(
      doctorId:
          session
                  .userPoolTokensResult
                  .valueOrNull
                  ?.idToken
                  .claims
                  .customClaims['custom:doctorId']
              as String?,
      id: user.userId,
      fullName: a[AuthUserAttributeKey.name] ?? '',
      email: a[AuthUserAttributeKey.email] ?? user.username,
      phoneNumber: a[AuthUserAttributeKey.phoneNumber],
      role: role,
    );
  }
}
