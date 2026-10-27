import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../config/aws_config.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  bool _configured = false;
  bool get isConfigured => _configured;

  /// REST API Gateway's Cognito authorizer uses an ID token (no OAuth scopes).
  /// Amplify refreshes expired session tokens; no token is cached in source.
  Future<String?> apiIdToken() async {
    if (!AwsConfig.useAws) return null;
    await initialize();
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    if (!session.isSignedIn) return null;
    final tokens = session.userPoolTokensResult.value;
    return tokens.idToken.raw;
  }

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
