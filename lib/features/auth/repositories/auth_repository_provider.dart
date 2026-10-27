import '../../../core/config/aws_config.dart';
import '../../../core/services/auth_service.dart';
import 'auth_repository.dart';

final AuthRepository authRepository = AwsConfig.useAws
    ? CognitoAuthRepository(AuthService.instance)
    : const LocalAuthRepository();
