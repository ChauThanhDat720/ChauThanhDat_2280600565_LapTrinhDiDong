import '../../../core/config/aws_config.dart';
import '../../../core/services/auth_service.dart';
import 'auth_repository.dart';
import 'shared_auth_repository.dart';

final AuthRepository authRepository = AwsConfig.useAws
    ? CognitoAuthRepository(AuthService.instance)
    : AwsConfig.useShared
    ? SharedAuthRepository.instance
    : const LocalAuthRepository();
