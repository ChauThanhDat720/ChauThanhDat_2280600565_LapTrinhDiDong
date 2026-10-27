import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../../../core/models/app_user.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/session/patient_session.dart';

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);
  final String message;
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
  });
  Future<void> confirmSignUp(String email, String code);
  Future<void> resendSignUpCode(String email);
  Future<AppUser?> signIn(String email, String password, {String? demoName});
  Future<AppUser?> restoreSession();
  Future<void> signOut();
  Future<void> startPasswordReset(String email);
  Future<void> confirmPasswordReset(String email, String code, String password);
}

class LocalAuthRepository implements AuthRepository {
  const LocalAuthRepository();
  @override
  bool get isDemo => true;
  @override
  Future<SignUpOutcome> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    await PatientSession.instance.update(
      name: name,
      email: email,
      phone: phone ?? '',
      dateOfBirth: '',
      gender: '',
      address: '',
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
    await PatientSession.instance.signIn(
      name: (demoName != null && demoName.trim().isNotEmpty) ? demoName.trim() : email.split('@').first,
      email: email,
    );
    return _user();
  }

  @override
  Future<AppUser?> restoreSession() async {
    await PatientSession.instance.restore();
    return PatientSession.instance.isLoggedIn ? _user() : null;
  }

  AppUser _user() {
    final email = PatientSession.instance.email.toLowerCase();
    final role = email.contains('doctor')
        ? UserRole.doctor
        : email.contains('admin')
        ? UserRole.admin
        : UserRole.patient;
    return AppUser(
      id: 'local-${PatientSession.instance.email}',
      fullName: PatientSession.instance.name,
      email: PatientSession.instance.email,
      phoneNumber: PatientSession.instance.phone,
      role: role,
    );
  }

  @override
  Future<void> signOut() => PatientSession.instance.clear();
  @override
  Future<void> startPasswordReset(String email) async =>
      throw const AuthRepositoryException(
        'Dịch vụ đăng nhập trực tuyến chưa được cấu hình.',
      );
  @override
  Future<void> confirmPasswordReset(
    String email,
    String code,
    String password,
  ) async => throw const AuthRepositoryException(
    'Dịch vụ đăng nhập trực tuyến chưa được cấu hình.',
  );
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
