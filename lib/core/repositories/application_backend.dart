import '../config/aws_config.dart';
import '../services/auth_service.dart';
import 'hospital_repositories.dart';

/// Shared dependency boundary. Supplying --dart-define-from-file selects AWS
/// for every screen using these repositories; local mode keeps demo behavior.
abstract final class ApplicationBackend {
  static final repositories = HospitalRepositories(
    useRemote: AwsConfig.useAws,
    accessTokenProvider: AuthService.instance.apiIdToken,
  );
}
