import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/patient_session.dart';
import '../domain/patient_profile.dart';

abstract interface class PatientRepository {
  Future<PatientProfile?> getMyProfile();
  Future<PatientProfile> createMyProfile(PatientProfile profile);
  Future<PatientProfile> updateMyProfile(PatientProfile profile);
}

class LocalPatientRepository implements PatientRepository {
  const LocalPatientRepository();

  @override
  Future<PatientProfile?> getMyProfile() async => PatientProfile(
    name: PatientSession.instance.name,
    email: PatientSession.instance.email,
    phone: PatientSession.instance.phone,
    dateOfBirth: PatientSession.instance.dateOfBirth,
    gender: PatientSession.instance.gender,
    address: PatientSession.instance.address,
    emergencyContactName: PatientSession.instance.emergencyContactName,
    emergencyContactPhone: PatientSession.instance.emergencyContactPhone,
  );

  @override
  Future<PatientProfile> updateMyProfile(PatientProfile profile) async {
    await PatientSession.instance.update(
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      dateOfBirth: profile.dateOfBirth,
      gender: profile.gender,
      address: profile.address,
      emergencyContactName: profile.emergencyContactName,
      emergencyContactPhone: profile.emergencyContactPhone,
    );
    return profile;
  }

  @override
  Future<PatientProfile> createMyProfile(PatientProfile profile) =>
      updateMyProfile(profile);
}

class RemotePatientRepository implements PatientRepository {
  const RemotePatientRepository(this._client);
  final ApiClient _client;

  @override
  Future<PatientProfile?> getMyProfile() async {
    try {
      final value = await _client.get('/patients/me');
      return value is Map<String, dynamic> ? _decode(value) : null;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<PatientProfile> createMyProfile(PatientProfile profile) async =>
      _decode(
        await _client.post('/patients/me', body: _body(profile))
            as Map<String, dynamic>,
      );

  @override
  Future<PatientProfile> updateMyProfile(PatientProfile profile) async =>
      _decode(
        await _client.patch('/patients/me', body: _body(profile))
            as Map<String, dynamic>,
      );
  Map<String, dynamic> _body(PatientProfile profile) {
    final result = profile.toJson();
    final dob = profile.dateOfBirth.trim();
    final parts = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(dob);
    if (parts != null) {
      final day = int.parse(parts[1]!),
          month = int.parse(parts[2]!),
          year = int.parse(parts[3]!);
      final date = DateTime.utc(year, month, day);
      if (date.day != day || date.month != month || date.year != year) {
        throw const ApiException(
          message: 'Ngày sinh không hợp lệ. Dùng dd/mm/yyyy.',
        );
      }
      result['dateOfBirth'] = date.toIso8601String().substring(0, 10);
    }
    return result;
  }

  PatientProfile _decode(Map<String, dynamic> value) {
    final data = Map<String, dynamic>.of(value);
    final dob = data['dateOfBirth'];
    if (dob is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dob)) {
      data['dateOfBirth'] =
          '${dob.substring(8, 10)}/${dob.substring(5, 7)}/${dob.substring(0, 4)}';
    }
    return PatientProfile.fromJson(data);
  }
}
