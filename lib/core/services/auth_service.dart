import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../config/aws_config.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  bool _configured = false;
  bool get isConfigured => _configured;
  Future<bool> initialize() async {
    if (!AwsConfig.isCognitoConfigured) return false;
    if (_configured) return true;
    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(AwsConfig.amplifyConfiguration);
      _configured = true;
      return true;
    } on AmplifyAlreadyConfiguredException {
      _configured = true;
      return true;
    }
  }
}
