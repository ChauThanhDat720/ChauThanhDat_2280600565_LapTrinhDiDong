import '../../features/appointments/data/appointment_repository.dart';
import '../../features/doctors/data/doctor_repository.dart';
import '../../features/profile/data/patient_repository.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';

/// Dependency boundary for a future Cognito/API connection.
///
/// The default is intentionally local. Set [useRemote] only after a deployed
/// API URL and an access-token provider are available.
class HospitalRepositories {
  HospitalRepositories({
    ApiConfig? apiConfig,
    AccessTokenProvider? accessTokenProvider,
    bool useRemote = false,
  }) {
    final config = apiConfig ?? ApiConfig();
    final canUseRemote = useRemote && config.isConfigured;
    final client = canUseRemote
        ? ApiClient(config: config, accessTokenProvider: accessTokenProvider)
        : null;
    doctors = client == null
        ? const LocalDoctorRepository()
        : RemoteDoctorRepository(client);
    appointments = client == null
        ? const LocalAppointmentRepository()
        : RemoteAppointmentRepository(client);
    patients = client == null
        ? const LocalPatientRepository()
        : RemotePatientRepository(client);
  }

  late final DoctorRepository doctors;
  late final AppointmentRepository appointments;
  late final PatientRepository patients;
}
