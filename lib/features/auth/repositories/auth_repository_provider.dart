import '../../../core/config/aws_config.dart';
import '../../../core/services/auth_service.dart';
import 'auth_repository.dart';

final AuthRepository authRepository = AwsConfig.isCognitoConfigured
    ? CognitoAuthRepository(AuthService.instance)
    : const LocalAuthRepository();
