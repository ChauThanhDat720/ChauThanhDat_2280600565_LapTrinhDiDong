class AwsConfig {
  static const region = String.fromEnvironment('AWS_REGION');
  static const userPoolId = String.fromEnvironment('COGNITO_USER_POOL_ID');
  static const appClientId = String.fromEnvironment('COGNITO_APP_CLIENT_ID');
  static bool get isCognitoConfigured =>
      region.isNotEmpty && userPoolId.isNotEmpty && appClientId.isNotEmpty;
  static String get amplifyConfiguration =>
      '''{"UserAgent":"smart-hospital","Version":"1.0","auth":{"plugins":{"awsCognitoAuthPlugin":{"UserAgent":"smart-hospital","Version":"1.0","IdentityManager":{"Default":{}},"CognitoUserPool":{"Default":{"PoolId":"$userPoolId","AppClientId":"$appClientId","Region":"$region"}}}}}}''';
}
