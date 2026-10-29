import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/patient_session.dart';
import 'auth_repository.dart';

/// Auth for the shared booking demo. Server validates every session and role.
/// Only a short-lived session token is kept on device; passwords stay on server.
class SharedAuthRepository implements AuthRepository {
  SharedAuthRepository({ApiConfig? config, ApiClient? client})
    : _config = config ?? ApiConfig(),
      _providedClient = client;
  static final instance = SharedAuthRepository();
  final ApiConfig _config;
  final ApiClient? _providedClient;
  late final _client =
      _providedClient ??
      ApiClient(config: _config, accessTokenProvider: accessToken);
  String get _tokenKey => 'shared_session_v1_${_config.baseUrl}';

  @override
  bool get isDemo => false;

  Future<String?> accessToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      throw AuthRepositoryException(error.message);
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
  }) => _request(() async {
    await _client.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone ?? '',
      },
    );
    return const SignUpOutcome(needsConfirmation: false);
  });

  @override
  Future<AppUser?> signIn(String email, String password, {String? demoName}) =>
      _request(() async {
        final result = await _client.post(
          '/auth/login',
          body: {'email': email, 'password': password},
        );
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(_tokenKey, result['token'] as String)) {
          throw const AuthRepositoryException('Không thể lưu phiên đăng nhập.');
        }
        return await _apply(result['user'] as Map<String, dynamic>);
      });

  @override
  Future<AppUser?> restoreSession() async {
    if (await accessToken() == null) return null;
    try {
      final result = await _client.get('/auth/me');
      return await _apply(result['user'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await (await SharedPreferences.getInstance()).remove(_tokenKey);
        await PatientSession.instance.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<AppUser> _apply(Map<String, dynamic> value) async {
    final role = value['role'] == 'doctor' ? UserRole.doctor : UserRole.patient;
    final user = AppUser(
      id: value['id'] as String,
      fullName: value['fullName'] as String,
      email: value['email'] as String,
      phoneNumber: value['phoneNumber'] as String?,
      role: role,
      doctorId: value['doctorId'] as String?,
      department: value['department'] as String?,
    );
    final session = PatientSession.instance;
    await session.restore();
    final sameUser = session.email == user.email;
    await session.signIn(
      name: user.fullName,
      email: user.email,
      phone: user.phoneNumber ?? '',
      role: role.name,
      doctorId: user.doctorId ?? '',
      department: user.department ?? '',
      dateOfBirth: sameUser ? session.dateOfBirth : '',
      gender: sameUser ? session.gender : '',
      address: sameUser ? session.address : '',
    );
    return user;
  }

  @override
  Future<void> signOut() => _request(() async {
    try {
      await _client.post('/auth/logout');
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
    }
    await (await SharedPreferences.getInstance()).remove(_tokenKey);
    await PatientSession.instance.clear();
  });

  Never _notSupported() => throw const AuthRepositoryException(
    'Bản demo chưa hỗ trợ xác thực email và khôi phục mật khẩu. Liên hệ người quản lý demo.',
  );
  @override
  Future<void> confirmSignUp(String email, String code) async =>
      _notSupported();
  @override
  Future<void> resendSignUpCode(String email) async => _notSupported();
  @override
  Future<void> startPasswordReset(String email) async => _notSupported();
  @override
  Future<void> confirmPasswordReset(
    String email,
    String code,
    String password,
  ) async => _notSupported();
}
