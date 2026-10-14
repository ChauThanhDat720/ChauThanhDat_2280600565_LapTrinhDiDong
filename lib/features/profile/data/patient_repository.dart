import '../../../core/network/api_client.dart';
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
    final value = await _client.get('/patients/me');
    return value is Map<String, dynamic>
        ? PatientProfile.fromJson(value)
        : null;
  }

  @override
  Future<PatientProfile> createMyProfile(PatientProfile profile) async =>
      PatientProfile.fromJson(
        await _client.post('/patients/me', body: profile.toJson())
            as Map<String, dynamic>,
      );

  @override
  Future<PatientProfile> updateMyProfile(PatientProfile profile) async =>
      PatientProfile.fromJson(
        await _client.patch('/patients/me', body: profile.toJson())
            as Map<String, dynamic>,
      );
}
