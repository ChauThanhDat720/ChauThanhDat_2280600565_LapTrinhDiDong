import '../config/aws_config.dart';
import '../services/auth_service.dart';
import '../../features/auth/repositories/shared_auth_repository.dart';
import 'hospital_repositories.dart';

/// Selects local, AWS, or the shared booking API using BACKEND_MODE.
abstract final class ApplicationBackend {
  static final repositories = HospitalRepositories(
    useRemote: AwsConfig.useAws || AwsConfig.useShared,
    sharedAppointmentsOnly: AwsConfig.useShared,
    accessTokenProvider: AwsConfig.useShared
        ? SharedAuthRepository.instance.accessToken
        : AuthService.instance.apiIdToken,
  );
}
