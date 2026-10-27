import '../../features/family/data/family_repository.dart';
import '../../features/teleconsultation/data/teleconsultation_repository.dart';
import '../../features/clinical_intake/data/clinical_intake_repository.dart';
import '../../features/appointments/data/appointment_repository.dart';
import '../../features/doctors/data/doctor_repository.dart';
import '../../features/profile/data/patient_repository.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';

/// Repository selection for local mode and the deployed AWS API.
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
    if (useRemote && !config.isConfigured) {
      throw StateError('Không thể bật AWS khi API_BASE_URL chưa hợp lệ.');
    }
    final canUseRemote = useRemote;
    final client = canUseRemote
        ? ApiClient(config: config, accessTokenProvider: accessTokenProvider)
        : null;
    _family = client == null ? null : RemoteFamilyRepository(client);
    teleconsultations = client == null
        ? const LocalTeleconsultationRepository()
        : RemoteTeleconsultationRepository(client);
    clinicalIntake = client == null
        ? const LocalClinicalIntakeRepository()
        : RemoteClinicalIntakeRepository(client);
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

  late final FamilyRepository? _family;
  FamilyRepository get family => _family ?? LocalFamilyRepository();
  late final TeleconsultationRepository teleconsultations;
  late final ClinicalIntakeRepository clinicalIntake;
  late final DoctorRepository doctors;
  late final AppointmentRepository appointments;
  late final PatientRepository patients;
}
